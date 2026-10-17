<?php

namespace Tests\Feature\Finance;

use App\Exceptions\DomainConflictException;
use App\Models\Debt;
use App\Models\DebtPayment;
use App\Models\FinancialTransaction;
use App\Models\User;
use App\Services\Finance\DebtService;
use App\Services\Finance\InstallmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class DebtAndInstallmentServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_partial_debt_payment_updates_remaining_and_creates_single_linked_expense_transaction(): void
    {
        $user = User::factory()->create(['username' => 'anzhel']);
        $debt = Debt::create([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'direction' => 'payable',
            'counterparty' => 'Budi Santoso',
            'principal_amount' => 1000000,
            'start_date' => '2026-10-01',
            'due_date' => '2026-10-25',
            'status' => 'active',
            'version' => 1,
        ]);

        $service = app(DebtService::class);
        $paymentId = (string) Str::uuid();
        $opId = (string) Str::uuid();

        $result = $service->recordPayment($user, [
            'id' => $paymentId,
            'debt_id' => $debt->id,
            'amount' => 250000,
            'paid_at' => '2026-10-15T10:00:00Z',
            'note' => 'Cicil tahap 1',
        ], $opId);

        $this->assertSame(750000, $debt->fresh()->remainingAmount());
        $this->assertSame(750000, $result['remaining_amount']);
        $this->assertSame('active', $result['derived_status']);

        $tx = FinancialTransaction::where('source_type', 'debt_payment')
            ->where('source_id', $paymentId)
            ->firstOrFail();

        $this->assertSame('expense', $tx->type);
        $this->assertSame(250000, $tx->amount_minor);
        $this->assertSame('posted', $tx->status);

        // Pay the remaining 750.000 -> derived status becomes paid
        $secondResult = $service->recordPayment($user, [
            'id' => (string) Str::uuid(),
            'debt_id' => $debt->id,
            'amount' => 750000,
            'paid_at' => '2026-10-17T10:00:00Z',
            'note' => 'Pelunasan',
        ], (string) Str::uuid());

        $this->assertSame(0, $debt->fresh()->remainingAmount());
        $this->assertSame('paid', $secondResult['derived_status']);
    }

    public function test_overpayment_above_remaining_debt_is_rejected_without_side_effects(): void
    {
        $user = User::factory()->create(['username' => 'anzhel']);
        $debt = Debt::create([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'direction' => 'payable',
            'counterparty' => 'Budi Santoso',
            'principal_amount' => 1000000,
            'start_date' => '2026-10-01',
            'due_date' => '2026-10-25',
            'status' => 'active',
            'version' => 1,
        ]);

        $service = app(DebtService::class);
        $service->recordPayment($user, [
            'id' => (string) Str::uuid(),
            'debt_id' => $debt->id,
            'amount' => 250000,
            'paid_at' => '2026-10-15T10:00:00Z',
        ], (string) Str::uuid());

        try {
            $service->recordPayment($user, [
                'id' => (string) Str::uuid(),
                'debt_id' => $debt->id,
                'amount' => 800000,
                'paid_at' => '2026-10-16T10:00:00Z',
            ], (string) Str::uuid());
            $this->fail('Expected DomainConflictException was not thrown.');
        } catch (DomainConflictException $e) {
            $this->assertSame(750000, $debt->fresh()->remainingAmount());
            $this->assertSame(1, DebtPayment::where('debt_id', $debt->id)->count());
            $this->assertSame(1, FinancialTransaction::where('user_id', $user->id)->count());
        }
    }

    public function test_reversing_posted_debt_payment_restores_remaining_balance_and_reverses_cash_transaction(): void
    {
        $user = User::factory()->create(['username' => 'anzhel']);
        $debt = Debt::create([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'direction' => 'payable',
            'counterparty' => 'Budi Santoso',
            'principal_amount' => 1000000,
            'start_date' => '2026-10-01',
            'due_date' => '2026-10-25',
            'status' => 'active',
            'version' => 1,
        ]);

        $service = app(DebtService::class);
        $paymentId = (string) Str::uuid();
        $service->recordPayment($user, [
            'id' => $paymentId,
            'debt_id' => $debt->id,
            'amount' => 250000,
            'paid_at' => '2026-10-15T10:00:00Z',
        ], (string) Str::uuid());

        $this->assertSame(750000, $debt->fresh()->remainingAmount());

        $service->reversePayment($user, $paymentId, 'Salah input nominal', (string) Str::uuid());

        $this->assertSame(1000000, $debt->fresh()->remainingAmount());
        $payment = DebtPayment::findOrFail($paymentId);
        $this->assertSame('reversed', $payment->status);
        $this->assertNotNull($payment->reversed_at);
        $this->assertSame('reversed', $payment->transaction->fresh()->status);
    }

    public function test_installment_plan_creates_terms_and_records_partial_and_full_term_payments(): void
    {
        $user = User::factory()->create(['username' => 'wina']);
        $service = app(InstallmentService::class);

        $plan = $service->createPlanWithInstallments($user, [
            'id' => (string) Str::uuid(),
            'title' => 'Laptop Kerja',
            'total_amount' => 6000000,
            'installment_count' => 7,
            'frequency' => 'monthly',
            'start_date' => '2026-08-17',
            'note' => 'Cicilan 7 bulan',
        ]);

        $this->assertCount(7, $plan->installments);
        $firstTerm = $plan->installments->firstWhere('sequence_no', 1);
        $lastTerm = $plan->installments->firstWhere('sequence_no', 7);
        $this->assertSame(857142, $firstTerm->planned_amount);
        $this->assertSame(857148, $lastTerm->planned_amount);

        $res = $service->recordPayment($user, [
            'id' => (string) Str::uuid(),
            'installment_id' => $firstTerm->id,
            'amount' => 400000,
            'paid_at' => '2026-08-17T09:00:00Z',
        ], (string) Str::uuid());

        $this->assertSame(457142, $res['remaining_term_amount']);
        $this->assertSame('partial', $firstTerm->fresh()->status);

        // Pay remaining terms and verify installment_plan SyncChange is emitted on completion
        $service->recordPayment($user, [
            'id' => (string) Str::uuid(),
            'installment_id' => $firstTerm->id,
            'amount' => 457142,
            'paid_at' => '2026-08-18T09:00:00Z',
        ], (string) Str::uuid());

        foreach ($plan->installments->where('sequence_no', '>', 1) as $term) {
            $service->recordPayment($user, [
                'id' => (string) Str::uuid(),
                'installment_id' => $term->id,
                'amount' => $term->planned_amount,
                'paid_at' => '2026-09-17T09:00:00Z',
            ], (string) Str::uuid());
        }

        $this->assertSame('completed', $plan->fresh()->status);
        $completedSyncChange = \App\Models\SyncChange::where('entity_type', 'installment_plan')
            ->where('entity_id', $plan->id)
            ->orderByDesc('sequence_id')
            ->first();
        $this->assertNotNull($completedSyncChange);
        $this->assertSame('completed', $completedSyncChange->payload['status']);
    }

    public function test_debt_payment_rejects_foreign_user_category_id(): void
    {
        $anzhel = User::factory()->create(['username' => 'anzhel']);
        $wina = User::factory()->create(['username' => 'wina']);
        $winaCat = \App\Models\Category::create([
            'id' => (string) Str::uuid(),
            'user_id' => $wina->id,
            'name' => 'Kategori Wina',
            'type' => 'expense',
            'icon_key' => 'receipt',
            'color_token' => 'slate',
            'is_system' => false,
            'version' => 1,
        ]);

        $debt = Debt::create([
            'id' => (string) Str::uuid(),
            'user_id' => $anzhel->id,
            'direction' => 'payable',
            'counterparty' => 'Budi',
            'principal_amount' => 500000,
            'start_date' => '2026-10-01',
            'status' => 'active',
            'version' => 1,
        ]);

        $this->expectException(\App\Exceptions\DomainValidationException::class);
        app(DebtService::class)->recordPayment($anzhel, [
            'id' => (string) Str::uuid(),
            'debt_id' => $debt->id,
            'amount' => 100000,
            'category_id' => $winaCat->id,
        ], (string) Str::uuid());
    }
}
