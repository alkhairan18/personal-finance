<?php

namespace App\Services\Finance;

use App\Exceptions\DomainValidationException;
use App\Models\AuditLog;
use App\Models\FinancialTransaction;
use App\Models\SyncChange;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TransactionService
{
    public function reverseTransaction(User $user, string $transactionId, ?string $reason = null, ?string $reversalId = null): FinancialTransaction
    {
        return DB::transaction(function () use ($user, $transactionId, $reason, $reversalId) {
            $original = FinancialTransaction::where('id', $transactionId)
                ->where('user_id', $user->id)
                ->lockForUpdate()
                ->first();

            if (! $original) {
                throw new DomainValidationException('Transaksi tidak ditemukan atau bukan milik pengguna.', [
                    'transaction_id' => ['Transaksi tidak ditemukan.'],
                ], 'NOT_FOUND');
            }

            if ($original->status === 'reversed') {
                throw new DomainValidationException('Transaksi sudah pernah dibatalkan/dikoreksi.', [
                    'transaction_id' => ['Transaksi sudah berstatus reversed.'],
                ]);
            }

            $original->update(['status' => 'reversed']);

            $compensatingType = $original->type === 'expense' ? 'income' : 'expense';
            $reversalTx = FinancialTransaction::create([
                'id' => $reversalId ?? (string) Str::uuid(),
                'user_id' => $user->id,
                'type' => $compensatingType,
                'amount_minor' => (int) $original->amount_minor,
                'transaction_date' => now()->toDateString(),
                'category_id' => $original->category_id,
                'payment_method' => $original->payment_method,
                'note' => trim('Koreksi/Pembatalan: ' . ($reason ?: ($original->note ?? ''))),
                'source_type' => 'reversal',
                'source_id' => $original->id,
                'status' => 'posted',
                'reverses_transaction_id' => $original->id,
            ]);

            AuditLog::create([
                'user_id' => $user->id,
                'entity_type' => 'financial_transaction',
                'entity_id' => $original->id,
                'action' => 'reverse_transaction',
                'metadata' => [
                    'reversal_transaction_id' => $reversalTx->id,
                    'reason' => $reason,
                ],
                'changed_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'financial_transaction',
                'entity_id' => $original->id,
                'entity_version' => 2,
                'operation' => 'upsert',
                'payload' => $this->serializeTransaction($original->fresh()),
                'created_at' => now(),
            ]);

            SyncChange::create([
                'user_id' => $user->id,
                'entity_type' => 'financial_transaction',
                'entity_id' => $reversalTx->id,
                'entity_version' => 1,
                'operation' => 'upsert',
                'payload' => $this->serializeTransaction($reversalTx),
                'created_at' => now(),
            ]);

            return $reversalTx;
        });
    }

    public function serializeTransaction(FinancialTransaction $tx): array
    {
        return [
            'id' => $tx->id,
            'type' => $tx->type,
            'amount_minor' => (int) $tx->amount_minor,
            'transaction_date' => $tx->transaction_date?->format('Y-m-d'),
            'category_id' => $tx->category_id,
            'payment_method' => $tx->payment_method,
            'note' => $tx->note,
            'source_type' => $tx->source_type,
            'source_id' => $tx->source_id,
            'status' => $tx->status,
            'reverses_transaction_id' => $tx->reverses_transaction_id,
            'updated_at' => $tx->updated_at?->toIso8601ZuluString(),
        ];
    }
}
