<?php

namespace App\Services\Sync;

use App\Exceptions\DomainConflictException;
use App\Exceptions\DomainValidationException;
use App\Models\AuditLog;
use App\Models\Category;
use App\Models\Debt;
use App\Models\FinancialTransaction;
use App\Models\InstallmentPlan;
use App\Models\SyncChange;
use App\Models\SyncOperation;
use App\Models\User;
use App\Models\Wishlist;
use App\Services\Finance\DebtService;
use App\Services\Finance\InstallmentService;
use App\Services\Finance\TransactionService;
use Illuminate\Support\Facades\DB;

class SyncPushService
{
    public function __construct(
        private readonly DebtService $debtService,
        private readonly InstallmentService $installmentService,
        private readonly TransactionService $transactionService
    ) {}

    public function processBatch(User $user, string $deviceId, array $operations): array
    {
        $results = [];

        foreach ($operations as $op) {
            $results[] = $this->processSingleOperation($user, $deviceId, $op);
        }

        return $results;
    }

    private function processSingleOperation(User $user, string $deviceId, array $op): array
    {
        $operationId = (string) $op['operation_id'];

        $existing = SyncOperation::where('user_id', $user->id)
            ->where('operation_id', $operationId)
            ->first();

        if ($existing) {
            $replayed = $existing->response_payload;
            $replayed['operation_id'] = $operationId;
            $replayed['status'] = 'replayed';
            return $replayed;
        }

        try {
            return DB::transaction(function () use ($user, $deviceId, $op, $operationId) {
                $outcome = $this->dispatchOperation($user, $op);
                $responsePayload = array_merge([
                    'operation_id' => $operationId,
                    'status' => 'applied',
                    'server_changed_at' => now()->utc()->toIso8601ZuluString(),
                ], $outcome);

                SyncOperation::create([
                    'user_id' => $user->id,
                    'device_id' => $deviceId,
                    'operation_id' => $operationId,
                    'result_status' => 'applied',
                    'response_payload' => $responsePayload,
                ]);

                return $responsePayload;
            });
        } catch (DomainConflictException $e) {
            $conflictPayload = [
                'operation_id' => $operationId,
                'status' => 'conflict',
                'entity_version' => $e->conflictState['version'] ?? null,
                'server_changed_at' => now()->utc()->toIso8601ZuluString(),
                'conflict_server_state' => $e->conflictState,
                'error' => [
                    'code' => $e->errorCode,
                    'message' => $e->getMessage(),
                ],
            ];

            SyncOperation::updateOrCreate(
                ['user_id' => $user->id, 'operation_id' => $operationId],
                [
                    'device_id' => $deviceId,
                    'result_status' => 'conflict',
                    'response_payload' => $conflictPayload,
                ]
            );

            return $conflictPayload;
        } catch (DomainValidationException $e) {
            $rejectedPayload = [
                'operation_id' => $operationId,
                'status' => 'rejected',
                'server_changed_at' => now()->utc()->toIso8601ZuluString(),
                'error' => [
                    'code' => $e->errorCode,
                    'message' => $e->getMessage(),
                    'details' => $e->details,
                ],
            ];

            SyncOperation::updateOrCreate(
                ['user_id' => $user->id, 'operation_id' => $operationId],
                [
                    'device_id' => $deviceId,
                    'result_status' => 'rejected',
                    'response_payload' => $rejectedPayload,
                ]
            );

            return $rejectedPayload;
        }
    }

    private function dispatchOperation(User $user, array $op): array
    {
        $entityType = (string) $op['entity_type'];
        $entityId = (string) $op['entity_id'];
        $action = (string) $op['action'];
        $baseVersion = isset($op['base_version']) ? (int) $op['base_version'] : null;
        $payload = is_array($op['payload'] ?? null) ? $op['payload'] : [];
        $operationId = (string) $op['operation_id'];

        return match ($action) {
            'record_debt_payment' => $this->handleRecordDebtPayment($user, $entityId, $payload, $operationId),
            'record_installment_payment' => $this->handleRecordInstallmentPayment($user, $entityId, $payload, $operationId),
            'reverse_transaction' => $this->handleReverseTransaction($user, $entityId, $payload),
            'reverse_debt_payment' => $this->handleReverseDebtPayment($user, $entityId, $payload, $operationId),
            'reverse_installment_payment' => $this->handleReverseInstallmentPayment($user, $entityId, $payload, $operationId),
            'upsert' => $this->handleUpsert($user, $entityType, $entityId, $baseVersion, $payload),
            'archive' => $this->handleArchive($user, $entityType, $entityId, $baseVersion),
            default => throw new DomainValidationException("Aksi sinkronisasi tidak didukung: {$action}"),
        };
    }

    private function handleRecordDebtPayment(User $user, string $entityId, array $payload, string $operationId): array
    {
        $data = array_merge($payload, ['id' => $entityId]);
        $result = $this->debtService->recordPayment($user, $data, $operationId);
        return [
            'entity_version' => 1,
            'result' => $result,
        ];
    }

    private function handleRecordInstallmentPayment(User $user, string $entityId, array $payload, string $operationId): array
    {
        $data = array_merge($payload, ['id' => $entityId]);
        $result = $this->installmentService->recordPayment($user, $data, $operationId);
        return [
            'entity_version' => 1,
            'result' => $result,
        ];
    }

    private function handleReverseTransaction(User $user, string $entityId, array $payload): array
    {
        $txId = (string) ($payload['transaction_id'] ?? $entityId);
        $reversal = $this->transactionService->reverseTransaction(
            $user,
            $txId,
            $payload['reason'] ?? null,
            $payload['reversal_transaction_id'] ?? null
        );

        return [
            'entity_version' => 2,
            'result' => ['reversal_transaction_id' => $reversal->id],
        ];
    }

    private function handleReverseDebtPayment(User $user, string $entityId, array $payload, string $operationId): array
    {
        $paymentId = (string) ($payload['debt_payment_id'] ?? $entityId);
        $result = $this->debtService->reversePayment($user, $paymentId, $payload['reason'] ?? null, $operationId);
        return [
            'entity_version' => 2,
            'result' => $result,
        ];
    }

    private function handleReverseInstallmentPayment(User $user, string $entityId, array $payload, string $operationId): array
    {
        $paymentId = (string) ($payload['installment_payment_id'] ?? $entityId);
        $result = $this->installmentService->reversePayment($user, $paymentId, $payload['reason'] ?? null, $operationId);
        return [
            'entity_version' => 2,
            'result' => $result,
        ];
    }

    private function handleUpsert(User $user, string $entityType, string $entityId, ?int $baseVersion, array $payload): array
    {
        return match ($entityType) {
            'wishlist' => $this->upsertWishlist($user, $entityId, $baseVersion, $payload),
            'debt' => $this->upsertDebt($user, $entityId, $baseVersion, $payload),
            'installment_plan' => $this->upsertInstallmentPlan($user, $entityId, $baseVersion, $payload),
            'financial_transaction' => $this->upsertFinancialTransaction($user, $entityId, $payload),
            'category' => $this->upsertCategory($user, $entityId, $baseVersion, $payload),
            default => throw new DomainValidationException("Upsert tidak diizinkan untuk entitas: {$entityType}"),
        };
    }

    private function upsertWishlist(User $user, string $entityId, ?int $baseVersion, array $payload): array
    {
        $existing = Wishlist::where('id', $entityId)->lockForUpdate()->first();
        if ($existing && $existing->user_id !== $user->id) {
            throw new DomainValidationException('Akses ditolak ke item wishlist pengguna lain.', [], 'FORBIDDEN');
        }

        $targetPrice = (int) ($payload['target_price'] ?? 0);
        $savedAmount = max(0, (int) ($payload['saved_amount'] ?? ($existing ? $existing->saved_amount : 0)));
        $title = trim((string) ($payload['title'] ?? ''));
        if ($title === '' || $targetPrice <= 0) {
            throw new DomainValidationException('Nama dan harga target wishlist wajib valid (> 0).');
        }

        $priority = (string) ($payload['priority'] ?? 'medium');
        if (! in_array($priority, ['low', 'medium', 'high'], true)) {
            throw new DomainValidationException('Prioritas wishlist tidak valid.');
        }

        $status = (string) ($payload['status'] ?? 'planned');
        if (! in_array($status, ['planned', 'saving', 'purchased', 'cancelled'], true)) {
            throw new DomainValidationException('Status wishlist tidak valid.');
        }

        if ($existing) {
            if ($baseVersion === null || (int) $existing->version !== $baseVersion) {
                throw new DomainConflictException(
                    'Versi wishlist di server telah berubah.',
                    $this->serializeWishlist($existing)
                );
            }

            $newVersion = (int) $existing->version + 1;
            $existing->update([
                'title' => $title,
                'target_price' => $targetPrice,
                'saved_amount' => $savedAmount,
                'target_date' => $payload['target_date'] ?? null,
                'priority' => $priority,
                'category' => $payload['category'] ?? null,
                'icon_key' => $payload['icon_key'] ?? null,
                'status' => $status,
                'note' => $payload['note'] ?? null,
                'version' => $newVersion,
            ]);
            $item = $existing->fresh();
        } else {
            $newVersion = 1;
            $item = Wishlist::create([
                'id' => $entityId,
                'user_id' => $user->id,
                'title' => $title,
                'target_price' => $targetPrice,
                'saved_amount' => $savedAmount,
                'target_date' => $payload['target_date'] ?? null,
                'priority' => $priority,
                'category' => $payload['category'] ?? null,
                'icon_key' => $payload['icon_key'] ?? null,
                'status' => $status,
                'note' => $payload['note'] ?? null,
                'version' => 1,
            ]);
        }

        SyncChange::create([
            'user_id' => $user->id,
            'entity_type' => 'wishlist',
            'entity_id' => $item->id,
            'entity_version' => $newVersion,
            'operation' => 'upsert',
            'payload' => $this->serializeWishlist($item),
            'created_at' => now(),
        ]);

        return ['entity_version' => $newVersion];
    }

    private function upsertDebt(User $user, string $entityId, ?int $baseVersion, array $payload): array
    {
        $existing = Debt::where('id', $entityId)->lockForUpdate()->first();
        if ($existing && $existing->user_id !== $user->id) {
            throw new DomainValidationException('Akses ditolak ke catatan hutang pengguna lain.', [], 'FORBIDDEN');
        }

        $direction = (string) ($payload['direction'] ?? '');
        $counterparty = trim((string) ($payload['counterparty'] ?? ''));
        $principalAmount = (int) ($payload['principal_amount'] ?? 0);
        $startDate = (string) ($payload['start_date'] ?? now()->toDateString());

        if (! in_array($direction, ['payable', 'receivable'], true) || $counterparty === '' || $principalAmount <= 0) {
            throw new DomainValidationException('Data hutang/piutang belum valid.');
        }

        if ($existing) {
            if ($baseVersion === null || (int) $existing->version !== $baseVersion) {
                throw new DomainConflictException(
                    'Versi catatan hutang di server telah berubah.',
                    $this->debtService->serializeDebt($existing)
                );
            }

            $paidAmount = (int) $existing->payments()->where('status', 'posted')->sum('amount');
            if ($principalAmount < $paidAmount) {
                throw new DomainValidationException('Nominal pokok tidak boleh lebih kecil dari total pembayaran yang sudah masuk.');
            }

            $newVersion = (int) $existing->version + 1;
            $existing->update([
                'direction' => $direction,
                'counterparty' => $counterparty,
                'principal_amount' => $principalAmount,
                'start_date' => $startDate,
                'due_date' => $payload['due_date'] ?? null,
                'note' => $payload['note'] ?? null,
                'version' => $newVersion,
            ]);
            $debt = $existing->fresh();
        } else {
            $newVersion = 1;
            $debt = Debt::create([
                'id' => $entityId,
                'user_id' => $user->id,
                'direction' => $direction,
                'counterparty' => $counterparty,
                'principal_amount' => $principalAmount,
                'start_date' => $startDate,
                'due_date' => $payload['due_date'] ?? null,
                'note' => $payload['note'] ?? null,
                'status' => 'active',
                'version' => 1,
            ]);
        }

        SyncChange::create([
            'user_id' => $user->id,
            'entity_type' => 'debt',
            'entity_id' => $debt->id,
            'entity_version' => $newVersion,
            'operation' => 'upsert',
            'payload' => $this->debtService->serializeDebt($debt),
            'created_at' => now(),
        ]);

        return ['entity_version' => $newVersion];
    }

    private function upsertInstallmentPlan(User $user, string $entityId, ?int $baseVersion, array $payload): array
    {
        $existing = InstallmentPlan::where('id', $entityId)->lockForUpdate()->first();
        if ($existing && $existing->user_id !== $user->id) {
            throw new DomainValidationException('Akses ditolak ke rencana cicilan pengguna lain.', [], 'FORBIDDEN');
        }

        if ($existing) {
            if ($baseVersion === null || (int) $existing->version !== $baseVersion) {
                throw new DomainConflictException(
                    'Versi rencana cicilan di server telah berubah.',
                    $this->installmentService->serializePlan($existing)
                );
            }

            $newVersion = (int) $existing->version + 1;
            $existing->update([
                'title' => trim((string) ($payload['title'] ?? $existing->title)),
                'note' => $payload['note'] ?? $existing->note,
                'version' => $newVersion,
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'installment_plan',
                'entity_id' => $existing->id,
                'entity_version' => $newVersion,
                'operation' => 'upsert',
                'payload' => $this->installmentService->serializePlan($existing->fresh()),
                'created_at' => now(),
            ]);

            return ['entity_version' => $newVersion];
        }

        $plan = $this->installmentService->createPlanWithInstallments(
            $user,
            array_merge($payload, ['id' => $entityId])
        );

        return ['entity_version' => (int) $plan->version];
    }

    private function upsertFinancialTransaction(User $user, string $entityId, array $payload): array
    {
        $existing = FinancialTransaction::where('id', $entityId)->lockForUpdate()->first();
        if ($existing) {
            if ($existing->user_id !== $user->id) {
                throw new DomainValidationException('Akses ditolak ke transaksi pengguna lain.', [], 'FORBIDDEN');
            }
            throw new DomainValidationException('Transaksi yang sudah terposting bersifat append-only; gunakan operasi reverse_transaction untuk koreksi.');
        }

        $type = (string) ($payload['type'] ?? '');
        $amountMinor = (int) ($payload['amount_minor'] ?? 0);
        $txDate = (string) ($payload['transaction_date'] ?? '');

        if (! in_array($type, ['income', 'expense'], true) || $amountMinor <= 0 || $txDate === '') {
            throw new DomainValidationException('Tipe, nominal (> 0), dan tanggal transaksi wajib valid.');
        }

        $categoryId = $payload['category_id'] ?? null;
        if ($categoryId) {
            $cat = Category::where('id', $categoryId)
                ->where(function ($q) use ($user) {
                    $q->whereNull('user_id')->orWhere('user_id', $user->id);
                })
                ->first();
            if (! $cat) {
                throw new DomainValidationException('Kategori transaksi tidak valid atau bukan milik pengguna.');
            }
        }

        $tx = FinancialTransaction::create([
            'id' => $entityId,
            'user_id' => $user->id,
            'type' => $type,
            'amount_minor' => $amountMinor,
            'transaction_date' => $txDate,
            'category_id' => $categoryId,
            'payment_method' => $payload['payment_method'] ?? null,
            'note' => $payload['note'] ?? null,
            'source_type' => null,
            'source_id' => null,
            'status' => 'posted',
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

        return ['entity_version' => 1];
    }

    private function upsertCategory(User $user, string $entityId, ?int $baseVersion, array $payload): array
    {
        $existing = Category::where('id', $entityId)->lockForUpdate()->first();
        if ($existing) {
            if ($existing->is_system || $existing->user_id !== $user->id) {
                throw new DomainValidationException('Kategori sistem atau milik pengguna lain tidak dapat diubah.', [], 'FORBIDDEN');
            }
            if ($baseVersion !== null && (int) $existing->version !== $baseVersion) {
                throw new DomainConflictException('Versi kategori telah berubah.', $existing->toArray());
            }
            $newVersion = (int) $existing->version + 1;
            $existing->update([
                'name' => trim((string) ($payload['name'] ?? $existing->name)),
                'type' => (string) ($payload['type'] ?? $existing->type),
                'icon_key' => $payload['icon_key'] ?? $existing->icon_key,
                'version' => $newVersion,
            ]);
            $cat = $existing->fresh();
        } else {
            $newVersion = 1;
            $cat = Category::create([
                'id' => $entityId,
                'user_id' => $user->id,
                'name' => trim((string) ($payload['name'] ?? 'Kategori Baru')),
                'type' => (string) ($payload['type'] ?? 'expense'),
                'icon_key' => $payload['icon_key'] ?? 'tag',
                'is_system' => false,
                'version' => 1,
            ]);
        }

        SyncChange::create([
            'user_id' => $user->id,
            'entity_type' => 'category',
            'entity_id' => $cat->id,
            'entity_version' => $newVersion,
            'operation' => 'upsert',
            'payload' => [
                'id' => $cat->id,
                'name' => $cat->name,
                'type' => $cat->type,
                'icon_key' => $cat->icon_key,
                'is_system' => (bool) $cat->is_system,
                'version' => $newVersion,
            ],
            'created_at' => now(),
        ]);

        return ['entity_version' => $newVersion];
    }

    private function handleArchive(User $user, string $entityType, string $entityId, ?int $baseVersion): array
    {
        $model = match ($entityType) {
            'wishlist' => Wishlist::where('id', $entityId)->lockForUpdate()->first(),
            'debt' => Debt::where('id', $entityId)->lockForUpdate()->first(),
            'installment_plan' => InstallmentPlan::where('id', $entityId)->lockForUpdate()->first(),
            'category' => Category::where('id', $entityId)->lockForUpdate()->first(),
            default => throw new DomainValidationException("Pengarsipan tidak didukung untuk: {$entityType}"),
        };

        if (! $model || $model->user_id !== $user->id) {
            throw new DomainValidationException('Record tidak ditemukan atau bukan milik pengguna.', [], 'FORBIDDEN');
        }

        if ($baseVersion !== null && (int) $model->version !== $baseVersion) {
            throw new DomainConflictException('Versi record telah berubah sebelum diarsipkan.', $model->toArray());
        }

        $newVersion = (int) $model->version + 1;
        $updates = ['version' => $newVersion, 'archived_at' => now()];
        if (in_array($entityType, ['debt', 'installment_plan'], true)) {
            $updates['status'] = 'archived';
        }
        $model->update($updates);

        AuditLog::create([
            'user_id' => $user->id,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'action' => 'archive',
            'metadata' => ['version' => $newVersion],
            'changed_at' => now(),
        ]);

        SyncChange::create([
            'user_id' => $user->id,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'entity_version' => $newVersion,
            'operation' => 'tombstone',
            'payload' => [
                'id' => $entityId,
                'archived_at' => $model->archived_at?->toIso8601ZuluString(),
            ],
            'created_at' => now(),
        ]);

        return ['entity_version' => $newVersion];
    }

    public function serializeWishlist(Wishlist $w): array
    {
        return [
            'id' => $w->id,
            'title' => $w->title,
            'target_price' => (int) $w->target_price,
            'saved_amount' => (int) ($w->saved_amount ?? 0),
            'target_date' => $w->target_date?->format('Y-m-d'),
            'priority' => $w->priority,
            'category' => $w->category,
            'icon_key' => $w->icon_key,
            'status' => $w->status,
            'note' => $w->note,
            'version' => (int) $w->version,
            'archived_at' => $w->archived_at?->toIso8601ZuluString(),
            'updated_at' => $w->updated_at?->toIso8601ZuluString(),
        ];
    }
}
