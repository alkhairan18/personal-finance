<?php

namespace App\Services\Finance;

use App\Exceptions\DomainConflictException;
use App\Exceptions\DomainValidationException;
use App\Models\AuditLog;
use App\Models\FinancialTransaction;
use App\Models\Installment;
use App\Models\InstallmentPayment;
use App\Models\InstallmentPlan;
use App\Models\SyncChange;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class InstallmentService
{
    public function __construct(
        private readonly InstallmentScheduleGenerator $scheduleGenerator,
        private readonly TransactionService $transactionService
    ) {}

    public function createPlanWithInstallments(User $user, array $planData): InstallmentPlan
    {
        return DB::transaction(function () use ($user, $planData) {
            $planId = $planData['id'] ?? (string) Str::uuid();
            $totalAmount = (int) ($planData['total_amount'] ?? 0);
            $count = (int) ($planData['installment_count'] ?? 0);
            $frequency = (string) ($planData['frequency'] ?? 'monthly');
            $startDate = (string) ($planData['start_date'] ?? now()->toDateString());

            $schedule = $this->scheduleGenerator->generate($totalAmount, $count, $frequency, $startDate);

            $plan = InstallmentPlan::create([
                'id' => $planId,
                'user_id' => $user->id,
                'title' => trim((string) ($planData['title'] ?? '')),
                'total_amount' => $totalAmount,
                'installment_count' => $count,
                'frequency' => $frequency,
                'start_date' => $startDate,
                'note' => $planData['note'] ?? null,
                'status' => 'active',
                'version' => 1,
            ]);

            $providedInstallments = $planData['installments'] ?? [];
            $idBySeq = [];
            foreach ($providedInstallments as $item) {
                if (isset($item['sequence_no'], $item['id'])) {
                    $idBySeq[(int) $item['sequence_no']] = (string) $item['id'];
                }
            }

            foreach ($schedule as $term) {
                $seq = $term['sequence_no'];
                $inst = Installment::create([
                    'id' => $idBySeq[$seq] ?? (string) Str::uuid(),
                    'user_id' => $user->id,
                    'plan_id' => $plan->id,
                    'sequence_no' => $seq,
                    'due_date' => $term['due_date'],
                    'planned_amount' => $term['planned_amount'],
                    'status' => 'planned',
                    'version' => 1,
                ]);

                SyncChange::create([
                    'user_id' => $user->id,
                    'entity_type' => 'installment',
                    'entity_id' => $inst->id,
                    'entity_version' => 1,
                    'operation' => 'upsert',
                    'payload' => $this->serializeInstallment($inst),
                    'created_at' => now(),
                ]);
            }

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'installment_plan',
                'entity_id' => $plan->id,
                'entity_version' => 1,
                'operation' => 'upsert',
                'payload' => $this->serializePlan($plan->fresh('installments')),
                'created_at' => now(),
            ]);

            return $plan->fresh('installments');
        });
    }

    public function recordPayment(User $user, array $data, string $operationId): array
    {
        $amount = (int) ($data['amount'] ?? 0);
        if ($amount <= 0) {
            throw new DomainValidationException('Nominal pembayaran cicilan harus lebih besar dari nol.', [
                'amount' => ['Nominal pembayaran cicilan harus lebih besar dari nol.'],
            ]);
        }

        return DB::transaction(function () use ($user, $data, $amount, $operationId) {
            $installment = Installment::where('id', $data['installment_id'] ?? '')
                ->where('user_id', $user->id)
                ->lockForUpdate()
                ->first();

            if (! $installment) {
                throw new DomainValidationException('Termin cicilan tidak ditemukan.', [
                    'installment_id' => ['Termin cicilan tidak ditemukan.'],
                ], 'NOT_FOUND');
            }

            $remainingTermBefore = $installment->remainingAmount();
            if ($amount > $remainingTermBefore) {
                throw new DomainConflictException(
                    'Nominal pembayaran melebihi sisa termin cicilan.',
                    [
                        'installment_id' => $installment->id,
                        'planned_amount' => (int) $installment->planned_amount,
                        'remaining_term_amount' => $remainingTermBefore,
                        'attempted_amount' => $amount,
                    ]
                );
            }

            $plan = $installment->plan()->lockForUpdate()->firstOrFail();
            $paymentId = $data['id'] ?? (string) Str::uuid();
            $transactionId = $data['transaction_id'] ?? (string) Str::uuid();
            $paidAt = isset($data['paid_at'])
                ? CarbonImmutable::parse($data['paid_at'])->utc()
                : CarbonImmutable::now('UTC');

            $categoryId = $data['category_id'] ?? null;
            if ($categoryId !== null) {
                $validCategory = \App\Models\Category::where('id', $categoryId)
                    ->where(function ($q) use ($user) {
                        $q->whereNull('user_id')->orWhere('user_id', $user->id);
                    })
                    ->exists();
                if (! $validCategory) {
                    throw new DomainValidationException('Kategori transaksi tidak valid.', [
                        'category_id' => ['Kategori transaksi tidak valid.'],
                    ]);
                }
            }

            $tx = FinancialTransaction::create([
                'id' => $transactionId,
                'user_id' => $user->id,
                'type' => 'expense',
                'amount_minor' => $amount,
                'transaction_date' => $paidAt->format('Y-m-d'),
                'category_id' => $categoryId,
                'payment_method' => $data['payment_method'] ?? null,
                'note' => $data['note'] ?? ("Cicilan {$plan->title} (Termin {$installment->sequence_no}/{$plan->installment_count})"),
                'source_type' => 'installment_payment',
                'source_id' => $paymentId,
                'status' => 'posted',
            ]);

            $payment = InstallmentPayment::create([
                'id' => $paymentId,
                'user_id' => $user->id,
                'installment_id' => $installment->id,
                'amount' => $amount,
                'paid_at' => $paidAt,
                'note' => $data['note'] ?? null,
                'transaction_id' => $tx->id,
                'operation_id' => $operationId,
                'status' => 'posted',
            ]);

            $remainingTermAfter = $installment->fresh()->remainingAmount();
            $termStatus = $remainingTermAfter === 0 ? 'paid' : 'partial';
            $installment->update([
                'status' => $termStatus,
                'version' => (int) $installment->version + 1,
            ]);

            $planUpdated = false;
            $allTermsPaid = $plan->installments()->get()->every(fn (Installment $t) => $t->remainingAmount() === 0);
            if ($allTermsPaid && $plan->status === 'active') {
                $plan->update([
                    'status' => 'completed',
                    'version' => (int) $plan->version + 1,
                ]);
                $planUpdated = true;
            }

            AuditLog::create([
                'user_id' => $user->id,
                'entity_type' => 'installment_payment',
                'entity_id' => $payment->id,
                'action' => 'record_installment_payment',
                'metadata' => [
                    'plan_id' => $plan->id,
                    'installment_id' => $installment->id,
                    'amount' => $amount,
                    'remaining_term_amount' => $remainingTermAfter,
                ],
                'changed_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'installment_payment',
                'entity_id' => $payment->id,
                'entity_version' => 1,
                'operation' => 'upsert',
                'payload' => $this->serializeInstallmentPayment($payment),
                'created_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'financial_transaction',
                'entity_id' => $tx->id,
                'entity_version' => 1,
                'operation' => 'upsert',
                'payload' => $this->transactionService->serializeTransaction($tx),
                'created_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'installment',
                'entity_id' => $installment->id,
                'entity_version' => (int) $installment->version,
                'operation' => 'upsert',
                'payload' => $this->serializeInstallment($installment->fresh()),
                'created_at' => now(),
            ]);

            if ($planUpdated) {
                SyncChange::create([
                    'user_id' => $user->id,
                    'entity_type' => 'installment_plan',
                    'entity_id' => $plan->id,
                    'entity_version' => (int) $plan->version,
                    'operation' => 'upsert',
                    'payload' => $this->serializePlan($plan->fresh()),
                    'created_at' => now(),
                ]);
            }

            return [
                'payment_id' => $payment->id,
                'transaction_id' => $tx->id,
                'installment_id' => $installment->id,
                'plan_id' => $plan->id,
                'remaining_term_amount' => $remainingTermAfter,
                'term_status' => $termStatus,
            ];
        });
    }

    public function reversePayment(User $user, string $installmentPaymentId, ?string $reason, string $operationId): array
    {
        return DB::transaction(function () use ($user, $installmentPaymentId, $reason, $operationId) {
            $payment = InstallmentPayment::where('id', $installmentPaymentId)
                ->where('user_id', $user->id)
                ->lockForUpdate()
                ->first();

            if (! $payment) {
                throw new DomainValidationException('Pembayaran cicilan tidak ditemukan.', [
                    'installment_payment_id' => ['Pembayaran cicilan tidak ditemukan.'],
                ], 'NOT_FOUND');
            }

            if ($payment->status === 'reversed') {
                throw new DomainValidationException('Pembayaran cicilan sudah dibatalkan.', [
                    'installment_payment_id' => ['Pembayaran cicilan sudah dibatalkan.'],
                ]);
            }

            $payment->update([
                'status' => 'reversed',
                'reversed_at' => now(),
            ]);

            $reversalTx = $this->transactionService->reverseTransaction(
                $user,
                $payment->transaction_id,
                $reason ?? 'Pembatalan pembayaran cicilan'
            );

            $installment = $payment->installment()->lockForUpdate()->firstOrFail();
            $remainingTermAfter = $installment->remainingAmount();
            $termStatus = $remainingTermAfter === (int) $installment->planned_amount
                ? 'planned'
                : ($remainingTermAfter === 0 ? 'paid' : 'partial');

            $installment->update([
                'status' => $termStatus,
                'version' => (int) $installment->version + 1,
            ]);

            $plan = $installment->plan()->lockForUpdate()->firstOrFail();
            $planUpdated = false;
            if ($plan->status === 'completed' && $remainingTermAfter > 0) {
                $plan->update([
                    'status' => 'active',
                    'version' => (int) $plan->version + 1,
                ]);
                $planUpdated = true;
            }

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'installment_payment',
                'entity_id' => $payment->id,
                'entity_version' => 2,
                'operation' => 'upsert',
                'payload' => $this->serializeInstallmentPayment($payment->fresh()),
                'created_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'installment',
                'entity_id' => $installment->id,
                'entity_version' => (int) $installment->version,
                'operation' => 'upsert',
                'payload' => $this->serializeInstallment($installment->fresh()),
                'created_at' => now(),
            ]);

            if ($planUpdated) {
                SyncChange::create([
                    'user_id' => $user->id,
                    'entity_type' => 'installment_plan',
                    'entity_id' => $plan->id,
                    'entity_version' => (int) $plan->version,
                    'operation' => 'upsert',
                    'payload' => $this->serializePlan($plan->fresh()),
                    'created_at' => now(),
                ]);
            }

            return [
                'payment_id' => $payment->id,
                'reversal_transaction_id' => $reversalTx->id,
                'installment_id' => $installment->id,
                'remaining_term_amount' => $remainingTermAfter,
                'term_status' => $termStatus,
            ];
        });
    }

    public function serializePlan(InstallmentPlan $plan): array
    {
        return [
            'id' => $plan->id,
            'title' => $plan->title,
            'total_amount' => (int) $plan->total_amount,
            'installment_count' => (int) $plan->installment_count,
            'frequency' => $plan->frequency,
            'start_date' => $plan->start_date?->format('Y-m-d'),
            'note' => $plan->note,
            'status' => $plan->status,
            'version' => (int) $plan->version,
            'archived_at' => $plan->archived_at?->toIso8601ZuluString(),
            'updated_at' => $plan->updated_at?->toIso8601ZuluString(),
        ];
    }

    public function serializeInstallment(Installment $installment): array
    {
        $remaining = $installment->remainingAmount();
        return [
            'id' => $installment->id,
            'plan_id' => $installment->plan_id,
            'sequence_no' => (int) $installment->sequence_no,
            'due_date' => $installment->due_date?->format('Y-m-d'),
            'planned_amount' => (int) $installment->planned_amount,
            'remaining_amount' => $remaining,
            'status' => $installment->status,
            'version' => (int) $installment->version,
            'updated_at' => $installment->updated_at?->toIso8601ZuluString(),
        ];
    }

    public function serializeInstallmentPayment(InstallmentPayment $payment): array
    {
        return [
            'id' => $payment->id,
            'installment_id' => $payment->installment_id,
            'amount' => (int) $payment->amount,
            'paid_at' => $payment->paid_at?->toIso8601ZuluString(),
            'note' => $payment->note,
            'transaction_id' => $payment->transaction_id,
            'operation_id' => $payment->operation_id,
            'status' => $payment->status,
            'reversed_at' => $payment->reversed_at?->toIso8601ZuluString(),
        ];
    }
}
