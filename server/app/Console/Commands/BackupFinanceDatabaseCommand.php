<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\File;

class BackupFinanceDatabaseCommand extends Command
{
    protected $signature = 'finance:backup-db {--output= : Optional custom output file path}';

    protected $description = 'Create a verifiable JSON snapshot backup of all finance tables for restore testing';

    public function handle(): int
    {
        $tables = [
            'users',
            'devices',
            'categories',
            'financial_transactions',
            'debts',
            'debt_payments',
            'installment_plans',
            'installments',
            'installment_payments',
            'wishlists',
            'sync_changes',
            'sync_operations',
            'audit_logs',
        ];

        $snapshot = [
            'generated_at' => now()->toIso8601String(),
            'tables' => [],
        ];

        foreach ($tables as $table) {
            $snapshot['tables'][$table] = DB::table($table)->get()->all();
        }

        $outputPath = (string) ($this->option('output') ?: storage_path('app/backups/finance_backup_' . now()->format('Ymd_His') . '.json'));
        File::ensureDirectoryExists(dirname($outputPath));
        File::put($outputPath, json_encode($snapshot, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));

        $this->info("Database backup written to: {$outputPath}");

        return self::SUCCESS;
    }
}
