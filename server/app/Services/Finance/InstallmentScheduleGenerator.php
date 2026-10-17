<?php

namespace App\Services\Finance;

use App\Exceptions\DomainValidationException;
use Carbon\CarbonImmutable;

class InstallmentScheduleGenerator
{
    /**
     * @return array<int, array{sequence_no: int, due_date: string, planned_amount: int}>
     */
    public function generate(
        int $totalAmount,
        int $count,
        string $frequency,
        string $startDate,
        int $customIntervalDays = 30
    ): array {
        if ($totalAmount <= 0) {
            throw new DomainValidationException('Total nominal cicilan harus lebih besar dari nol.', [
                'total_amount' => ['Total nominal cicilan harus lebih besar dari nol.'],
            ]);
        }

        if ($count <= 0 || $count > 120) {
            throw new DomainValidationException('Jumlah termin harus antara 1 sampai 120.', [
                'installment_count' => ['Jumlah termin harus antara 1 sampai 120.'],
            ]);
        }

        if ($totalAmount < $count) {
            throw new DomainValidationException('Total nominal cicilan tidak boleh lebih kecil dari jumlah termin.', [
                'total_amount' => ['Total nominal cicilan tidak boleh lebih kecil dari jumlah termin.'],
            ]);
        }

        $baseAmount = intdiv($totalAmount, $count);
        $lastAmount = $totalAmount - ($baseAmount * ($count - 1));
        $start = CarbonImmutable::parse($startDate)->startOfDay();

        $schedule = [];
        for ($i = 1; $i <= $count; $i++) {
            $offset = $i - 1;
            $dueDate = match ($frequency) {
                'weekly' => $start->addWeeks($offset),
                'monthly' => $start->addMonthsNoOverflow($offset),
                'custom' => $start->addDays($offset * max(1, $customIntervalDays)),
                default => throw new DomainValidationException("Frekuensi cicilan tidak valid: {$frequency}"),
            };

            $schedule[] = [
                'sequence_no' => $i,
                'due_date' => $dueDate->format('Y-m-d'),
                'planned_amount' => $i === $count ? $lastAmount : $baseAmount,
            ];
        }

        return $schedule;
    }
}
