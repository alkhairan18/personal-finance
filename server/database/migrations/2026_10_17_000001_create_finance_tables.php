<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('personal_access_tokens', function (Blueprint $table) {
            $table->id();
            $table->uuidMorphs('tokenable');
            $table->text('name');
            $table->string('token', 64)->unique();
            $table->text('abilities')->nullable();
            $table->timestampTz('last_used_at')->nullable();
            $table->timestampTz('expires_at')->nullable()->index();
            $table->timestampsTz();
        });

        Schema::create('devices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('device_name')->nullable();
            $table->timestampTz('last_seen_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'revoked_at']);
        });

        Schema::create('categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->nullable()->constrained('users')->cascadeOnDelete();
            $table->string('name');
            $table->string('type'); // income, expense, both
            $table->string('icon_key')->nullable();
            $table->boolean('is_system')->default(false);
            $table->integer('version')->default(1);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'type']);
        });

        Schema::create('financial_transactions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type'); // income, expense
            $table->bigInteger('amount_minor');
            $table->date('transaction_date');
            $table->foreignUuid('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('payment_method')->nullable();
            $table->text('note')->nullable();
            $table->string('source_type')->nullable(); // debt_payment, installment_payment, reversal
            $table->uuid('source_id')->nullable();
            $table->string('status')->default('posted'); // posted, reversed
            $table->uuid('reverses_transaction_id')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'transaction_date']);
            $table->index(['user_id', 'status']);
            $table->unique(['user_id', 'source_type', 'source_id'], 'fin_tx_unique_user_source');
        });

        Schema::create('debts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('direction'); // payable, receivable
            $table->string('counterparty');
            $table->bigInteger('principal_amount');
            $table->date('start_date');
            $table->date('due_date')->nullable();
            $table->text('note')->nullable();
            $table->string('status')->default('active'); // active, archived
            $table->integer('version')->default(1);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'due_date']);
            $table->index(['user_id', 'status']);
        });

        Schema::create('debt_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('debt_id')->constrained('debts')->cascadeOnDelete();
            $table->bigInteger('amount');
            $table->timestampTz('paid_at');
            $table->text('note')->nullable();
            $table->foreignUuid('transaction_id')->unique()->constrained('financial_transactions')->cascadeOnDelete();
            $table->uuid('operation_id');
            $table->string('status')->default('posted'); // posted, reversed
            $table->timestampTz('reversed_at')->nullable();
            $table->timestampsTz();

            $table->unique(['user_id', 'operation_id']);
            $table->index(['debt_id', 'status']);
        });

        Schema::create('installment_plans', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('title');
            $table->bigInteger('total_amount');
            $table->integer('installment_count');
            $table->string('frequency'); // weekly, monthly, custom
            $table->date('start_date');
            $table->text('note')->nullable();
            $table->string('status')->default('active'); // active, completed, archived
            $table->integer('version')->default(1);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'status']);
        });

        Schema::create('installments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('plan_id')->constrained('installment_plans')->cascadeOnDelete();
            $table->integer('sequence_no');
            $table->date('due_date');
            $table->bigInteger('planned_amount');
            $table->string('status')->default('planned'); // planned, partial, paid
            $table->integer('version')->default(1);
            $table->timestampsTz();

            $table->unique(['plan_id', 'sequence_no']);
            $table->index(['user_id', 'due_date']);
        });

        Schema::create('installment_payments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignUuid('installment_id')->constrained('installments')->cascadeOnDelete();
            $table->bigInteger('amount');
            $table->timestampTz('paid_at');
            $table->text('note')->nullable();
            $table->foreignUuid('transaction_id')->unique()->constrained('financial_transactions')->cascadeOnDelete();
            $table->uuid('operation_id');
            $table->string('status')->default('posted'); // posted, reversed
            $table->timestampTz('reversed_at')->nullable();
            $table->timestampsTz();

            $table->unique(['user_id', 'operation_id']);
            $table->index(['installment_id', 'status']);
        });

        Schema::create('wishlists', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('title');
            $table->bigInteger('target_price');
            $table->bigInteger('saved_amount')->default(0);
            $table->date('target_date')->nullable();
            $table->string('priority')->default('medium'); // low, medium, high
            $table->string('category')->nullable();
            $table->string('icon_key')->nullable();
            $table->string('status')->default('planned'); // planned, saving, purchased, cancelled
            $table->text('note')->nullable();
            $table->integer('version')->default(1);
            $table->timestampTz('archived_at')->nullable();
            $table->timestampsTz();

            $table->index(['user_id', 'status']);
        });

        Schema::create('sync_operations', function (Blueprint $table) {
            $table->id();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->uuid('device_id')->nullable();
            $table->uuid('operation_id');
            $table->string('result_status'); // applied, conflict, rejected
            $table->json('response_payload');
            $table->timestampsTz();

            $table->unique(['user_id', 'operation_id']);
        });

        Schema::create('sync_changes', function (Blueprint $table) {
            $table->bigIncrements('sequence_id');
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('entity_type');
            $table->uuid('entity_id');
            $table->integer('entity_version')->nullable();
            $table->string('operation'); // upsert, tombstone
            $table->json('payload')->nullable();
            $table->timestampTz('created_at')->useCurrent();

            $table->index(['user_id', 'sequence_id']);
        });

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('entity_type');
            $table->uuid('entity_id');
            $table->string('action');
            $table->json('metadata')->nullable();
            $table->timestampTz('changed_at')->useCurrent();

            $table->index(['user_id', 'changed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('sync_changes');
        Schema::dropIfExists('sync_operations');
        Schema::dropIfExists('wishlists');
        Schema::dropIfExists('installment_payments');
        Schema::dropIfExists('installments');
        Schema::dropIfExists('installment_plans');
        Schema::dropIfExists('debt_payments');
        Schema::dropIfExists('debts');
        Schema::dropIfExists('financial_transactions');
        Schema::dropIfExists('categories');
        Schema::dropIfExists('devices');
        Schema::dropIfExists('personal_access_tokens');
    }
};
