<?php

namespace App\Services\Finance;

use App\Exceptions\DomainConflictException;
use App\Exceptions\DomainValidationException;
use App\Models\AuditLog;
use App\Models\Debt;
use App\Models\DebtPayment;
use App\Models\FinancialTransaction;
use App\Models\SyncChange;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DebtService
{
    public function __construct(
        private readonly TransactionService $transactionService
    ) {}

    public function recordPayment(User $user, array $data, string $operationId): array
    {
        $amount = (int) ($data['amount'] ?? 0);
        if ($amount <= 0) {
            throw new DomainValidationException('Nominal pembayaran harus lebih besar dari nol.', [
                'amount' => ['Nominal pembayaran harus lebih besar dari nol.'],
            ]);
        }

        return DB::transaction(function () use ($user, $data, $amount, $operationId) {
            $debt = Debt::where('id', $data['debt_id'] ?? '')
                ->where('user_id', $user->id)
                ->lockForUpdate()
                ->first();

            if (! $debt) {
                throw new DomainValidationException('Catatan hutang/piutang tidak ditemukan.', [
                    'debt_id' => ['Catatan hutang/piutang tidak ditemukan.'],
                ], 'NOT_FOUND');
            }

            $remainingBefore = $debt->remainingAmount();
            if ($amount > $remainingBefore) {
                throw new DomainConflictException(
                    'Nominal pembayaran melebihi sisa kewajiban saat ini.',
                    [
                        'debt_id' => $debt->id,
                        'principal_amount' => (int) $debt->principal_amount,
                        'remaining_amount' => $remainingBefore,
                        'attempted_amount' => $amount,
                    ]
                );
            }

            $paymentId = $data['id'] ?? (string) Str::uuid();
            $transactionId = $data['transaction_id'] ?? (string) Str::uuid();
            $paidAt = isset($data['paid_at'])
                ? CarbonImmutable::parse($data['paid_at'])->utc()
                : CarbonImmutable::now('UTC');

            $txType = $debt->direction === 'payable' ? 'expense' : 'income';
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
                'type' => $txType,
                'amount_minor' => $amount,
                'transaction_date' => $paidAt->format('Y-m-d'),
                'category_id' => $categoryId,
                'payment_method' => $data['payment_method'] ?? null,
                'note' => $data['note'] ?? ("Pembayaran {$debt->counterparty}"),
                'source_type' => 'debt_payment',
                'source_id' => $paymentId,
                'status' => 'posted',
            ]);

            $payment = DebtPayment::create([
                'id' => $paymentId,
                'user_id' => $user->id,
                'debt_id' => $debt->id,
                'amount' => $amount,
                'paid_at' => $paidAt,
                'note' => $data['note'] ?? null,
                'transaction_id' => $tx->id,
                'operation_id' => $operationId,
                'status' => 'posted',
            ]);

            $remainingAfter = $debt->fresh()->remainingAmount();
            $derivedStatus = $this->deriveDebtStatus($debt, $remainingAfter);

            AuditLog::create([
                'user_id' => $user->id,
                'entity_type' => 'debt_payment',
                'entity_id' => $payment->id,
                'action' => 'record_debt_payment',
                'metadata' => [
                    'debt_id' => $debt->id,
                    'amount' => $amount,
                    'remaining_after' => $remainingAfter,
                    'transaction_id' => $tx->id,
                ],
                'changed_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'debt_payment',
                'entity_id' => $payment->id,
                'entity_version' => 1,
                'operation' => 'upsert',
                'payload' => $this->serializeDebtPayment($payment),
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
                'entity_type' => 'debt',
                'entity_id' => $debt->id,
                'entity_version' => (int) $debt->version,
                'operation' => 'upsert',
                'payload' => $this->serializeDebt($debt->fresh()),
                'created_at' => now(),
            ]);

            return [
                'payment_id' => $payment->id,
                'transaction_id' => $tx->id,
                'debt_id' => $debt->id,
                'remaining_amount' => $remainingAfter,
                'derived_status' => $derivedStatus,
            ];
        });
    }

    public function reversePayment(User $user, string $debtPaymentId, ?string $reason, string $operationId): array
    {
        return DB::transaction(function () use ($user, $debtPaymentId, $reason, $operationId) {
            $payment = DebtPayment::where('id', $debtPaymentId)
                ->where('user_id', $user->id)
                ->lockForUpdate()
                ->first();

            if (! $payment) {
                throw new DomainValidationException('Pembayaran hutang tidak ditemukan.', [
                    'debt_payment_id' => ['Pembayaran hutang tidak ditemukan.'],
                ], 'NOT_FOUND');
            }

            if ($payment->status === 'reversed') {
                throw new DomainValidationException('Pembayaran ini sudah pernah dibatalkan.', [
                    'debt_payment_id' => ['Pembayaran sudah dibatalkan.'],
                ]);
            }

            $payment->update([
                'status' => 'reversed',
                'reversed_at' => now(),
            ]);

            $reversalTx = $this->transactionService->reverseTransaction(
                $user,
                $payment->transaction_id,
                $reason ?? 'Pembatalan pembayaran hutang'
            );

            $debt = $payment->debt()->lockForUpdate()->firstOrFail();
            $remainingAfter = $debt->remainingAmount();

            AuditLog::create([
                'user_id' => $user->id,
                'entity_type' => 'debt_payment',
                'entity_id' => $payment->id,
                'action' => 'reverse_debt_payment',
                'metadata' => [
                    'debt_id' => $debt->id,
                    'reason' => $reason,
                    'operation_id' => $operationId,
                    'remaining_after' => $remainingAfter,
                ],
                'changed_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'debt_payment',
                'entity_id' => $payment->id,
                'entity_version' => 2,
                'operation' => 'upsert',
                'payload' => $this->serializeDebtPayment($payment->fresh()),
                'created_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'debt',
                'entity_id' => $debt->id,
                'entity_version' => (int) $debt->version,
                'operation' => 'upsert',
                'payload' => $this->serializeDebt($debt->fresh()),
                'created_at' => now(),
            ]);

            return [
                'payment_id' => $payment->id,
                'reversal_transaction_id' => $reversalTx->id,
                'debt_id' => $debt->id,
                'remaining_amount' => $remainingAfter,
                'derived_status' => $this->deriveDebtStatus($debt, $remainingAfter),
            ];
        });
    }

    public function deriveDebtStatus(Debt $debt, ?int $remaining = null): string
    {
        if ($debt->status === 'archived') {
            return 'archived';
        }

        $rem = $remaining ?? $debt->remainingAmount();
        if ($rem <= 0) {
            return 'paid';
        }

        if ($debt->due_date && $debt->due_date->lt(now()->startOfDay())) {
            return 'overdue';
        }

        return 'active';
    }

    public function serializeDebt(Debt $debt): array
    {
        $remaining = $debt->remainingAmount();
        return [
            'id' => $debt->id,
            'direction' => $debt->direction,
            'counterparty' => $debt->counterparty,
            'principal_amount' => (int) $debt->principal_amount,
            'remaining_amount' => $remaining,
            'start_date' => $debt->start_date?->format('Y-m-d'),
            'due_date' => $debt->due_date?->format('Y-m-d'),
            'note' => $debt->note,
            'status' => $debt->status,
            'derived_status' => $this->deriveDebtStatus($debt, $remaining),
            'version' => (int) $debt->version,
            'archived_at' => $debt->archived_at?->toIso8601ZuluString(),
            'updated_at' => $debt->updated_at?->toIso8601ZuluString(),
        ];
    }

    public function serializeDebtPayment(DebtPayment $payment): array
    {
        return [
            'id' => $payment->id,
            'debt_id' => $payment->debt_id,
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
