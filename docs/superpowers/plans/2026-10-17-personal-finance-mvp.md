# Personal Finance MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the offline-first Android application (`mobile/` in Flutter + Riverpod + Drift) and REST synchronization backend (`server/` in Laravel + PostgreSQL + Sanctum) for Anzhel (Account A) and Wina (Account W) to record expenses, income, debts/receivables, flexible installments, wishlists, reminders, and offline PDF reports.

**Architecture:** Local-first mobile architecture where all user mutations write atomically to a per-account encrypted SQLite database (`Drift` + `flutter_secure_storage`) and a local `sync_outbox` queue, rendering immediately in the UI without network wait. When online, a cursor-based and idempotent sync engine pushes queued domain operations (`POST /api/v1/sync/push`) and pulls server change-log entries (`GET /api/v1/sync/pull`) from a Laravel API backed by PostgreSQL that enforces strict per-user isolation and atomic double-entry-like cash links for debt and installment payments.

**Tech Stack:**
- **Server:** PHP 8.2 (`C:\xampp\php\php.exe`), Composer, Laravel 11, Laravel Sanctum, PostgreSQL (production/local dev) & SQLite (fast automated feature tests).
- **Mobile:** Flutter (Dart 3 null-safe), `flutter_riverpod`, `drift` + `sqlite3_flutter_libs`, `flutter_secure_storage`, `dio`, `google_fonts` (`Plus Jakarta Sans` & `JetBrains Mono`), `phosphor_flutter`, `pdf` + `printing`, `uuid`, `intl`.

**Spec:** `F:\personal-finance\docs\superpowers\specs\2026-10-17-personal-finance-design.md` (along with baseline specs in `F:\`: `PRD_Aplikasi_Keuangan_Pribadi (1).md`, `README.md`, `ARCHITECTURE.md`, `DATABASE_DESIGN.md`, `API_SPEC.md`, `AUTH_DESIGN.md`, `DEVELOPMENT_RULES.md`).

## Global Constraints

- **Monorepo Layout:** `F:\personal-finance\` with `docs/`, `server/`, and `mobile/`.
- **Integer Money Only:** All Rupiah amounts (`amount_minor`, `principal_amount`, `amount`, `total_amount`, `planned_amount`, `target_price`) MUST be 64-bit integers (`BIGINT` in SQL, `int` in PHP/Dart) representing whole Rupiah (`amount > 0`). `double`/`float` for money is strictly forbidden.
- **Account Isolation:** Two administrative accounts (`anzhel` and `wina`), no public registration. Server derives `user_id` exclusively from `request()->user()->id` (Sanctum token) and never trusts `user_id` from client payloads. Local mobile database files are isolated per user (`finance_<user_id>.db`).
- **Audit-Safe Finance:** Posted transactions (`financial_transactions`), debt payments (`debt_payments`), and installment payments (`installment_payments`) are never hard-deleted or silently overwritten; corrections use explicit reversal operations (`reverse_transaction`, `reverse_debt_payment`, `reverse_installment_payment`).
- **Single Cash Impact per Payment:** Recording a debt payment (`payable` -> `expense`, `receivable` -> `income`) or installment payment (`expense`) atomically creates exactly one linked `financial_transaction` with unique `(user_id, source_type, source_id)`.
- **Installment Rounding Rule:** For total $T$ and count $N$, terms $1 \dots (N-1)$ equal $\lfloor T / N \rfloor$ (`intdiv(T, N)` / `T ~/ N`) and term $N$ equals $T - \lfloor T / N \rfloor \times (N - 1)$.
- **Visual Design ("Swiss Ledger" - Option A):** Light palette (`#FAF9F6` bg, `#FFFFFF` surface, `#F1F0EC` subtle, `#E5E4DF` `1px` border, `#141413` ink, `#6E6D68` muted, `#0F766E` deep teal accent, `#B45309` warn, `#B91C1C` danger) + Dark palette (`#121316` bg, `#1A1C20` surface, `#23262B` subtle, `#2C3036` border, `#F3F4F6` text, `#8E95A2` muted, `#0D9488` accent). `Plus Jakarta Sans` for UI copy, `JetBrains Mono` with `FontFeature.tabularFigures()` for all numbers/dates, `phosphor_flutter` icons, **zero emojis**, **zero em-dashes**.

## Review Focus

1. **Non-divisible installment total rounding (`total_amount = 6000000`, `installment_count = 7`):** Terms 1..6 must be `857142` and term 7 must be `857148` so the sum of all scheduled terms equals `6000000` with zero Rupiah discrepancy (pinned in Task 2 & Task 4).
2. **Idempotent replay of `record_debt_payment` and `record_installment_payment` on network retry:** Sending the same `(user_id, operation_id)` twice to `POST /api/v1/sync/push` must return `"status": "replayed"` and must NOT create a second payment row or a second `financial_transaction` (pinned in Task 3).
3. **Over-payment rejection on debt or installment:** Pushing a `record_debt_payment` whose `amount` exceeds `principal_amount - sum(active debt_payments)` must return `"status": "conflict"` (or `"rejected"`) without inserting a payment or cash transaction (pinned in Task 2 & Task 3).
4. **Cross-account IDOR attempt in sync push and pull:** Account A (`anzhel`) pushing an `upsert`, `archive`, or `record_debt_payment` referencing an `entity_id` or `debt_id` belonging to Account W (`wina`), or supplying W's `user_id` in payload, must be rejected without modifying W's data, and `GET /api/v1/sync/pull` for A must never return W's `sync_changes` (pinned in Task 3).
5. **Atomic reversal of a posted debt payment (`reverse_debt_payment`):** Reversing a posted `debt_payment` must mark the payment reversed and reverse its linked `financial_transaction` in the same transaction so the debt's remaining balance increases back by the reversed amount and historical records remain intact (pinned in Task 2 & Task 3).

---

### Task 1: Monorepo Setup, Laravel Server Foundation, Schema Migrations & Auth API (`server/`)

**Files:**
- Create: `F:\personal-finance\.gitignore`
- Create: `F:\personal-finance\README.md` (and copy baseline docs from `F:\*.md` into `F:\personal-finance\docs\`)
- Create: `F:\personal-finance\server\` (Laravel 11 project via Composer using `C:\xampp\php\php.exe`)
- Create: `F:\personal-finance\server\database\migrations\2026_10_17_000001_create_finance_tables.php`
- Create: `F:\personal-finance\server\database\seeders\SystemCategorySeeder.php`
- Create: `F:\personal-finance\server\app\Console\Commands\CreateFinanceUserCommand.php`
- Create: `F:\personal-finance\server\app\Http\Controllers\Api\V1\AuthController.php`
- Create: `F:\personal-finance\server\app\Http\Controllers\Api\V1\HealthController.php`
- Create: `F:\personal-finance\server\app\Support\ApiErrorResponse.php`
- Modify: `F:\personal-finance\server\routes\api.php`
- Modify: `F:\personal-finance\server\bootstrap\app.php`
- Test: `F:\personal-finance\server\tests\Feature\Api\V1\AuthAndHealthTest.php`

**Interfaces:**
- Consumes: Baseline specifications in `F:\DATABASE_DESIGN.md`, `F:\API_SPEC.md`, `F:\AUTH_DESIGN.md`.
- Produces:
  - Database tables: `users` (UUID PK), `devices`, `categories`, `financial_transactions`, `debts`, `debt_payments`, `installment_plans`, `installments`, `installment_payments`, `wishlists`, `sync_operations`, `sync_changes`, `audit_logs`.
  - CLI command: `php artisan finance:create-user {username} {name} {--password=} {--email=}`
  - Endpoints:
    - `GET /api/v1/health` -> `{"data": {"status": "ok"}}`
    - `POST /api/v1/auth/login` -> validates `username`, `password`, `device_id` (UUID), `device_name`, upserts `devices`, issues Sanctum token bound to `device_id`, returns `{"data": {"token": "...", "token_type": "Bearer", "expires_at": "...", "user": {"id": "...", "name": "...", "username": "..."}}}`
    - `GET /api/v1/auth/me` -> returns authenticated user + active device info; rejects revoked devices (`revoked_at != null`) with `401 UNAUTHENTICATED`
    - `POST /api/v1/auth/logout` -> revokes current access token and returns `{"data": {"logged_out": true}}`
  - Error formatter `ApiErrorResponse::make(string $code, string $message, array $details = [], int $status = 400)` returning `{"error": {"code": ..., "message": ..., "details": ..., "request_id": ...}}`.

- [ ] **Step 1: Prepare monorepo directories, Composer, and scaffold `server/`**

Copy `F:\PRD_Aplikasi_Keuangan_Pribadi (1).md` (as `docs/PRD.md`), `F:\ARCHITECTURE.md`, `F:\DATABASE_DESIGN.md`, `F:\API_SPEC.md`, `F:\AUTH_DESIGN.md`, `F:\DEVELOPMENT_RULES.md`, and `F:\README.md` into `F:\personal-finance\docs\`. Ensure Composer is available (install `composer.phar` to `F:\personal-finance\tools\composer.phar` if not globally installed) and create the Laravel 11 application in `F:\personal-finance\server\` using `C:\xampp\php\php.exe`. Initialize git in `F:\personal-finance\`.

- [ ] **Step 2: Write the failing auth, device revocation, CLI user creation, and health feature tests**

Create `F:\personal-finance\server\tests\Feature\Api\V1\AuthAndHealthTest.php`:
```php
<?php

namespace Tests\Feature\Api\V1;

use App\Models\Device;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AuthAndHealthTest extends TestCase
{
    use RefreshDatabase;

    public function test_health_endpoint_returns_minimal_status(): void
    {
        $this->getJson('/api/v1/health')
            ->assertOk()
            ->assertExactJson(['data' => ['status' => 'ok']]);
    }

    public function test_artisan_command_creates_anzhel_and_wina_accounts_with_hashed_passwords(): void
    {
        $this->artisan('finance:create-user', [
            'username' => 'anzhel',
            'name' => 'Anzhel',
            '--password' => 'SecretPass123!',
        ])->assertExitCode(0);

        $user = User::where('username', 'anzhel')->firstOrFail();
        $this->assertNotSame('SecretPass123!', $user->password);
        $this->assertTrue(password_verify('SecretPass123!', $user->password));
    }

    public function test_login_issues_token_and_binds_device_and_logout_revokes_token(): void
    {
        $user = User::factory()->create([
            'username' => 'anzhel',
            'name' => 'Anzhel',
            'password' => bcrypt('SecretPass123!'),
            'is_active' => true,
        ]);
        $deviceId = (string) Str::uuid();

        $login = $this->postJson('/api/v1/auth/login', [
            'username' => 'anzhel',
            'password' => 'SecretPass123!',
            'device_id' => $deviceId,
            'device_name' => 'Samsung S23 Anzhel',
        ])->assertOk();

        $token = $login->json('data.token');
        $this->assertNotEmpty($token);
        $this->assertSame($user->id, $login->json('data.user.id'));

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.user.username', 'anzhel');

        $this->withToken($token)->postJson('/api/v1/auth/logout')
            ->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_revoked_device_cannot_access_protected_endpoints(): void
    {
        $user = User::factory()->create([
            'username' => 'wina',
            'name' => 'Wina',
            'password' => bcrypt('WinaPass123!'),
            'is_active' => true,
        ]);
        $deviceId = (string) Str::uuid();

        $login = $this->postJson('/api/v1/auth/login', [
            'username' => 'wina',
            'password' => 'WinaPass123!',
            'device_id' => $deviceId,
            'device_name' => 'Pixel Wina',
        ])->assertOk();

        $token = $login->json('data.token');
        Device::where('id', $deviceId)->update(['revoked_at' => now()]);

        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `C:\xampp\php\php.exe artisan test --filter=AuthAndHealthTest` (in `F:\personal-finance\server`)
Expected: FAIL (routes, migrations, models, and command do not exist yet).

- [ ] **Step 4: Implement migrations, Eloquent models, `SystemCategorySeeder`, `CreateFinanceUserCommand`, and Auth/Health controllers**

Create `2026_10_17_000001_create_finance_tables.php` defining all tables and constraints from `DATABASE_DESIGN.md` (including `reversed_at` / `status` on `debt_payments` and `installment_payments` for audit-safe reversals, unique `(user_id, source_type, source_id)` on `financial_transactions` where `status = 'posted'`, and unique `(user_id, operation_id)` on `sync_operations`, `debt_payments`, and `installment_payments`). Implement UUID-based models (`User`, `Device`, `Category`, `FinancialTransaction`, `Debt`, `DebtPayment`, `InstallmentPlan`, `Installment`, `InstallmentPayment`, `Wishlist`, `SyncOperation`, `SyncChange`, `AuditLog`), `SystemCategorySeeder` with the 12 default Indonesian categories and Phosphor `icon_key` values, `CreateFinanceUserCommand`, `EnsureActiveDeviceToken` middleware, `AuthController`, `HealthController`, and consistent JSON error formatting in `bootstrap/app.php`.

- [ ] **Step 5: Run test to verify it passes**

Run: `C:\xampp\php\php.exe artisan test --filter=AuthAndHealthTest`
Expected: PASS (4 tests, all assertions green).

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat(server): add database schema, system categories, user CLI, and auth API"
```

---

### Task 2: Server Domain Services — Finance Math, Debt/Installment Payments & Reversals

**Files:**
- Create: `F:\personal-finance\server\app\Services\Finance\InstallmentScheduleGenerator.php`
- Create: `F:\personal-finance\server\app\Services\Finance\TransactionService.php`
- Create: `F:\personal-finance\server\app\Services\Finance\DebtService.php`
- Create: `F:\personal-finance\server\app\Services\Finance\InstallmentService.php`
- Test: `F:\personal-finance\server\tests\Unit\Finance\InstallmentScheduleGeneratorTest.php`
- Test: `F:\personal-finance\server\tests\Feature\Finance\DebtAndInstallmentServiceTest.php`

**Interfaces:**
- Consumes: Eloquent models from Task 1 (`User`, `FinancialTransaction`, `Debt`, `DebtPayment`, `InstallmentPlan`, `Installment`, `InstallmentPayment`, `AuditLog`, `SyncChange`).
- Produces:
  - `InstallmentScheduleGenerator::generate(int $totalAmount, int $count, string $frequency, string $startDate): array` -> returns list of `['sequence_no' => int, 'due_date' => 'YYYY-MM-DD', 'planned_amount' => int]` where sum of `planned_amount` equals `$totalAmount` and rounding remainder is placed on the last term.
  - `DebtService::recordPayment(User $user, array $data, string $operationId): array` -> validates ownership, `amount > 0`, and `amount <= remaining_amount`; atomically creates `DebtPayment`, linked `FinancialTransaction` (`payable` -> `expense`, `receivable` -> `income`, `source_type = 'debt_payment'`, `source_id = payment.id`), `AuditLog`, and `SyncChange` entries. Throws `DomainValidationException` (422/409) if `amount > remaining_amount`.
  - `DebtService::reversePayment(User $user, string $debtPaymentId, ?string $reason, string $operationId): array` -> marks `DebtPayment` reversed, marks linked `FinancialTransaction` reversed and creates compensating reversal entry, recalculates remaining balance, writes `AuditLog` and `SyncChange`.
  - `InstallmentService::createPlanWithInstallments(User $user, array $planData): InstallmentPlan`
  - `InstallmentService::recordPayment(User $user, array $data, string $operationId): array` -> validates term ownership and `amount <= remaining_term_amount`; atomically creates `InstallmentPayment`, linked `FinancialTransaction` (`expense`, `source_type = 'installment_payment'`), updates plan completion status if all terms paid, writes `AuditLog` and `SyncChange`.
  - `InstallmentService::reversePayment(User $user, string $installmentPaymentId, ?string $reason, string $operationId): array`
  - `TransactionService::reverseTransaction(User $user, string $transactionId, ?string $reason): FinancialTransaction`

- [ ] **Step 1: Write the failing unit & feature tests for 7-term rounding, partial debt payments, over-payment rejection, and payment reversal**

Create `InstallmentScheduleGeneratorTest.php` and `DebtAndInstallmentServiceTest.php`:
```php
<?php

namespace Tests\Unit\Finance;

use App\Services\Finance\InstallmentScheduleGenerator;
use PHPUnit\Framework\TestCase;

class InstallmentScheduleGeneratorTest extends TestCase
{
    public function test_seven_monthly_installments_put_rounding_remainder_on_last_term(): void
    {
        $generator = new InstallmentScheduleGenerator();
        $schedule = $generator->generate(6000000, 7, 'monthly', '2026-08-17');

        $this->assertCount(7, $schedule);
        for ($i = 0; $i < 6; $i++) {
            $this->assertSame(857142, $schedule[$i]['planned_amount']);
        }
        $this->assertSame(857148, $schedule[6]['planned_amount']);
        $this->assertSame(6000000, array_sum(array_column($schedule, 'planned_amount')));
        $this->assertSame('2026-08-17', $schedule[0]['due_date']);
        $this->assertSame('2027-02-17', $schedule[6]['due_date']);
    }
}
```
And in `DebtAndInstallmentServiceTest.php`, assert:
1. Paying `250000` on a `1000000` `payable` debt leaves `750000` remaining and creates exactly 1 `expense` transaction (`source_type = 'debt_payment'`).
2. Paying another `750000` transitions derived status to `paid` (`remaining_amount === 0`).
3. Attempting to pay `800000` when `750000` remains throws `DomainConflictException` and leaves `debt_payments` and `financial_transactions` counts unchanged.
4. Reversing the `250000` payment restores remaining balance to `1000000` and marks the linked transaction reversed while keeping historical records.

- [ ] **Step 2: Run tests to verify they fail**

Run: `C:\xampp\php\php.exe artisan test --filter=InstallmentScheduleGeneratorTest` and `C:\xampp\php\php.exe artisan test --filter=DebtAndInstallmentServiceTest`
Expected: FAIL (classes not found).

- [ ] **Step 3: Implement `InstallmentScheduleGenerator`, `TransactionService`, `DebtService`, and `InstallmentService`**

Use integer division `intdiv($totalAmount, $count)` for terms `1..($count - 1)` and `$totalAmount - ($base * ($count - 1))` for term `$count`. Wrap all multi-table writes in `DB::transaction(...)` with `lockForUpdate()` on the parent `Debt` or `Installment` row before checking remaining balance to prevent race-condition over-payments.

- [ ] **Step 4: Run tests to verify they pass**

Run: `C:\xampp\php\php.exe artisan test --filter="InstallmentScheduleGeneratorTest|DebtAndInstallmentServiceTest"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/app/Services/Finance server/tests
git commit -m "feat(server): implement integer finance services, 7-term schedule generator, and atomic payment reversals"
```

---

### Task 3: Server Sync Engine — Idempotent Push, Conflict Detection, IDOR Guard & Cursor Pull

**Files:**
- Create: `F:\personal-finance\server\app\Services\Sync\SyncPushService.php`
- Create: `F:\personal-finance\server\app\Services\Sync\SyncPullService.php`
- Create: `F:\personal-finance\server\app\Http\Controllers\Api\V1\SyncController.php`
- Create: `F:\personal-finance\server\app\Http\Requests\Api\V1\SyncPushRequest.php`
- Modify: `F:\personal-finance\server\routes\api.php`
- Test: `F:\personal-finance\server\tests\Feature\Api\V1\SyncPushPullTest.php`

**Interfaces:**
- Consumes: Finance services from Task 2, Auth & Models from Task 1.
- Produces:
  - `POST /api/v1/sync/push` accepting `{"device_id": "uuid", "operations": [...]}` (max 100 operations) and returning `{"data": {"results": [{"operation_id": "...", "status": "applied|replayed|conflict|rejected", "entity_version": 1, "server_changed_at": "...", "conflict_server_state": {...}, "error": {...}}]}}`.
  - `GET /api/v1/sync/pull?cursor=<opaque>&limit=500` returning `{"data": {"changes": [...], "next_cursor": "...", "has_more": bool}}`.

- [ ] **Step 1: Write the failing feature tests covering idempotent replay, version conflict, cross-account IDOR protection, and cursor pull pagination**

Create `F:\personal-finance\server\tests\Feature\Api\V1\SyncPushPullTest.php` testing:
1. Pushing `upsert` on `wishlist`, `debt`, `installment_plan`, `financial_transaction`, and `record_debt_payment` applies changes and emits `sync_changes`.
2. Re-sending the exact same `operation_id` for `record_debt_payment` returns `"status": "replayed"` and creates only 1 `debt_payment` and 1 `financial_transaction` in the database.
3. Sending `upsert` on a `wishlist` with stale `base_version: 1` when server is at `version: 2` returns `"status": "conflict"` along with `conflict_server_state`.
4. **IDOR test:** User A (`anzhel`) attempting to push an update or `record_debt_payment` against User W's (`wina`) `debt_id` or `wishlist` `entity_id`, or passing `"user_id": $wina->id` in payload, gets `"status": "rejected"` (`FORBIDDEN` / `NOT_FOUND`) and Wina's records remain untouched.
5. **Pull isolation & pagination test:** `GET /api/v1/sync/pull?limit=2` as Anzhel returns only Anzhel's changes in ascending `sequence_id` order with `has_more: true` and `next_cursor`, and pulling with `next_cursor` returns the remaining changes with zero items from Wina.

- [ ] **Step 2: Run test to verify it fails**

Run: `C:\xampp\php\php.exe artisan test --filter=SyncPushPullTest`
Expected: FAIL (404 on `/api/v1/sync/push` and `/api/v1/sync/pull`).

- [ ] **Step 3: Implement `SyncPushService`, `SyncPullService`, `SyncPushRequest`, and `SyncController`**

In `SyncPushService::processBatch(User $user, string $deviceId, array $operations)`:
- Check `SyncOperation::where('user_id', $user->id)->where('operation_id', $op['operation_id'])->first()`. If found, return stored `response_payload` with `"status" => "replayed"`.
- Dispatch each operation inside `DB::transaction(...)` by `entity_type` and `action` (`upsert`, `archive`, `record_debt_payment`, `record_installment_payment`, `reverse_transaction`, `reverse_debt_payment`, `reverse_installment_payment`), enforcing ownership (`user_id === $user->id`) on both primary entities and foreign keys (`category_id`, `debt_id`, `installment_id`), checking `base_version` on mutable versioned entities, recording `SyncChange` (`operation: 'upsert'` or `'tombstone'`), and persisting `SyncOperation`.
In `SyncPullService::pull(User $user, ?string $cursor, int $limit)`:
- Decode base64 JSON cursor `{"seq": int}` (default `0`), query `SyncChange::where('user_id', $user->id)->where('sequence_id', '>', $lastSeq)->orderBy('sequence_id')->limit($limit + 1)->get()`, determine `has_more`, and encode `next_cursor`.

- [ ] **Step 4: Run all server tests to verify they pass**

Run: `C:\xampp\php\php.exe artisan test`
Expected: PASS (all unit and feature tests green).

- [ ] **Step 5: Commit**

```bash
git add server/
git commit -m "feat(server): add idempotent sync push/pull endpoints with conflict detection and IDOR isolation"
```

---

### Task 4: Flutter Mobile Setup, Domain Calculators, Encrypted Drift Database & Offline Outbox (`mobile/`)

**Files:**
- Create: `F:\personal-finance\mobile\` (Flutter Android project)
- Modify: `F:\personal-finance\mobile\pubspec.yaml`
- Create: `F:\personal-finance\mobile\lib\core\money\rupiah_formatter.dart`
- Create: `F:\personal-finance\mobile\lib\core\finance\installment_calculator.dart`
- Create: `F:\personal-finance\mobile\lib\core\finance\obligation_status.dart`
- Create: `F:\personal-finance\mobile\lib\core\database\app_database.dart`
- Create: `F:\personal-finance\mobile\lib\core\database\database_key_manager.dart`
- Create: `F:\personal-finance\mobile\lib\features\transactions\data\transaction_repository.dart`
- Create: `F:\personal-finance\mobile\lib\features\debts\data\debt_repository.dart`
- Create: `F:\personal-finance\mobile\lib\features\installments\data\installment_repository.dart`
- Create: `F:\personal-finance\mobile\lib\features\wishlist\data\wishlist_repository.dart`
- Test: `F:\personal-finance\mobile\test\core\finance_calculator_test.dart`
- Test: `F:\personal-finance\mobile\test\core\offline_repository_outbox_test.dart`

**Interfaces:**
- Consumes: Local schema & sync outbox design from `F:\DATABASE_DESIGN.md` and `F:\ARCHITECTURE.md`.
- Produces:
  - `InstallmentCalculator.generateSchedule({required int totalAmount, required int count, required String frequency, required DateTime startDate}) -> List<PlannedInstallmentTerm>`
  - `ObligationStatusCalculator.deriveStatus({required int remainingAmount, required DateTime? dueDate, required DateTime today}) -> ObligationStatus` (`paid`, `overdue`, `dueToday`, `upcoming`, `activeNoDueDate`)
  - `AppDatabase` (Drift database isolated per `userId`: `finance_<userId>.db`) with tables: `LocalCategories`, `LocalTransactions`, `LocalDebts`, `LocalDebtPayments`, `LocalInstallmentPlans`, `LocalInstallments`, `LocalInstallmentPayments`, `LocalWishlists`, `SyncOutbox`, `SyncMetadata`, `SyncConflicts`.
  - Repositories (`TransactionRepository`, `DebtRepository`, `InstallmentRepository`, `WishlistRepository`) that execute every local write and its `SyncOutbox` insertion inside a single `db.transaction(() async { ... })` with stable `operation_id` UUID.

- [ ] **Step 1: Ensure Flutter SDK is available and scaffold `F:\personal-finance\mobile\`**

Check for Flutter SDK; if not installed, download the stable Flutter Windows SDK into `F:\flutter` and add `F:\flutter\bin` to the session PATH. Create the Flutter Android project in `F:\personal-finance\mobile` and configure `pubspec.yaml` with `flutter_riverpod`, `drift`, `sqlite3_flutter_libs`, `path_provider`, `path`, `flutter_secure_storage`, `dio`, `uuid`, `intl`, `google_fonts`, `phosphor_flutter`, `pdf`, `printing`, and dev dependencies `drift_dev`, `build_runner`, `flutter_test`, `sqlite3`.

- [ ] **Step 2: Write the failing Dart unit tests for `InstallmentCalculator`, `ObligationStatusCalculator`, and atomic `Drift` + `SyncOutbox` offline operations**

Create `F:\personal-finance\mobile\test\core\finance_calculator_test.dart` and `F:\personal-finance\mobile\test\core\offline_repository_outbox_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/finance/installment_calculator.dart';
import 'package:personal_finance/core/finance/obligation_status.dart';

void main() {
  test('7 monthly installments of Rp 6.000.000 put remainder on 7th term', () {
    final terms = InstallmentCalculator.generateSchedule(
      totalAmount: 6000000,
      count: 7,
      frequency: 'monthly',
      startDate: DateTime(2026, 8, 17),
    );
    expect(terms.length, 7);
    for (var i = 0; i < 6; i++) {
      expect(terms[i].plannedAmount, 857142);
    }
    expect(terms[6].plannedAmount, 857148);
    expect(terms.fold<int>(0, (sum, t) => sum + t.plannedAmount), 6000000);
  });

  test('deriveStatus returns paid when remaining is 0 even if dueDate passed', () {
    final status = ObligationStatusCalculator.deriveStatus(
      remainingAmount: 0,
      dueDate: DateTime(2026, 10, 1),
      today: DateTime(2026, 10, 17),
    );
    expect(status, ObligationStatus.paid);
  });
}
```
And in `offline_repository_outbox_test.dart`, verify using an in-memory `NativeDatabase.memory()` that:
1. Creating an expense while offline inserts into `local_transactions` AND `sync_outbox` atomically with `amountMinor > 0`.
2. Recording a partial debt payment (`250000` on `1000000`) inserts `local_debt_payments`, inserts the linked `local_transactions` (`sourceType: 'debt_payment'`), updates remaining debt to `750000`, and queues a single `record_debt_payment` operation in `sync_outbox`.
3. Reversing a transaction marks the original `reversed`, creates the compensating entry, and queues `reverse_transaction` in `sync_outbox`.

- [ ] **Step 3: Run Flutter tests to verify they fail**

Run: `flutter test test/core/` (in `F:\personal-finance\mobile`)
Expected: FAIL (files not implemented yet).

- [ ] **Step 4: Implement calculators, Drift `AppDatabase`, `DatabaseKeyManager`, and local repositories**

Implement `InstallmentCalculator`, `ObligationStatusCalculator`, `RupiahFormatter` (integer-only formatting `Rp 45.000` and parser), `AppDatabase` with all 11 tables and default system categories seed, and the 4 domain repositories (`TransactionRepository`, `DebtRepository`, `InstallmentRepository`, `WishlistRepository`).

- [ ] **Step 5: Run Flutter tests to verify they pass**

Run: `flutter test test/core/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/
git commit -m "feat(mobile): add Drift local database, finance calculators, and offline outbox repositories"
```

---

### Task 5: Mobile Auth, Sync Engine (Push/Pull/Conflict/Retry) & Safe Logout Flow

**Files:**
- Create: `F:\personal-finance\mobile\lib\core\network\api_client.dart`
- Create: `F:\personal-finance\mobile\lib\features\auth\data\auth_repository.dart`
- Create: `F:\personal-finance\mobile\lib\core\sync\sync_engine.dart`
- Test: `F:\personal-finance\mobile\test\core\sync_engine_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` from Task 4, `/api/v1/*` contract from Task 1 & Task 3.
- Produces:
  - `AuthRepository`: `login(username, password)`, `getCurrentSession()`, `checkLogoutSafety()`, `logout({bool forceDiscardPending = false})`.
  - `SyncEngine.synchronize()`:
    1. Sends pending `sync_outbox` rows in batches of up to 100 to `POST /api/v1/sync/push` reusing each row's existing `operation_id`.
    2. Marks `applied` and `replayed` rows as `synced`.
    3. Moves `conflict` rows into `sync_conflicts` with server snapshot and marks outbox item `conflict`.
    4. Marks `rejected` (422) rows as `rejected` with error message without infinite retry; keeps network errors as `pending` with incremented `attempt_count`.
    5. Pulls pages from `GET /api/v1/sync/pull?cursor=...`, applies all changes (`upsert` and `tombstone`) in one SQLite transaction per page, and updates `last_pull_cursor` in `sync_metadata` only after the transaction succeeds.

- [ ] **Step 1: Write the failing unit/integration tests for `SyncEngine` and `AuthRepository` logout safety**

Create `F:\personal-finance\mobile\test\core\sync_engine_test.dart` verifying:
1. Network timeout during push preserves the exact same `operation_id` on the next retry.
2. `applied` and `replayed` responses mark the outbox item `synced`.
3. `conflict` response records a `SyncConflict` entry containing both local and server snapshots.
4. Paginated pull (`has_more: true` then `has_more: false`) applies `upsert` and `tombstone` records atomically and advances `last_pull_cursor` only after page commit.
5. `AuthRepository.checkLogoutSafety()` returns `LogoutSafetyCheck(hasPendingOperations: true, pendingCount: N)` when `sync_outbox` has unsynced items.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/sync_engine_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `ApiClient`, `AuthRepository`, and `SyncEngine`**

Implement `ApiClient` (attaching Bearer token from secure storage), `AuthRepository` (managing per-user database lifecycle `finance_<user_id>.db` so switching between Anzhel and Wina never mixes local caches), and `SyncEngine` with exponential backoff + jitter calculation for transient network errors.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/sync_engine_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/network mobile/lib/core/sync mobile/lib/features/auth mobile/test/core/sync_engine_test.dart
git commit -m "feat(mobile): implement idempotent sync engine, cursor pull, conflict storage, and safe logout"
```

---

### Task 6: Mobile UI — "Swiss Ledger" Theme, 5-Point Shell, Quick-Add Numpad & Buku Kas (Dashboard + Transactions)

**Files:**
- Create: `F:\personal-finance\mobile\lib\app\theme\swiss_ledger_theme.dart`
- Create: `F:\personal-finance\mobile\lib\app\providers\app_providers.dart`
- Create: `F:\personal-finance\mobile\lib\features\auth\presentation\login_screen.dart`
- Create: `F:\personal-finance\mobile\lib\app\shell\main_shell_screen.dart`
- Create: `F:\personal-finance\mobile\lib\features\transactions\presentation\quick_add_transaction_sheet.dart`
- Create: `F:\personal-finance\mobile\lib\features\dashboard\presentation\buku_kas_screen.dart`
- Modify: `F:\personal-finance\mobile\lib\main.dart`
- Test: `F:\personal-finance\mobile\test\features\quick_add_and_buku_kas_widget_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, repositories, and `SyncEngine` from Tasks 4 & 5.
- Produces:
  - `SwissLedgerTheme`: light (`#FAF9F6` bg, `#FFFFFF` surface, `#E5E4DF` `1px` border, `#141413` ink, `#0F766E` deep teal accent) and dark (`#121316` bg, `#1A1C20` surface, `#2C3036` border, `#0D9488` accent) `ThemeData`, `SwissLedgerTypography.monoTabular()` (`JetBrains Mono` with `FontFeature.tabularFigures()`), and Phosphor icon mapping (`CategoryIconMapper`).
  - `LoginScreen`: username/password login + server URL configuration for private deployment.
  - `MainShellScreen`: persistent header (Active Account badge `Anzhel`/`Wina` + Sync Status pill showing `Tersinkron` or `Offline · N antrean`) and 5-item bottom bar (`Buku Kas`, `Kewajiban`, center `+ Catat` button, `Wishlist`, `Laporan`).
  - `QuickAddTransactionSheet`: custom tactile integer numpad (`1-9`, `.000`, `0`, backspace), `Pengeluaran`/`Pemasukan` toggle, Phosphor category chips, payment method chips (`QRIS / E-Wallet`, `Tunai`, `Transfer Bank`), date picker, and instant local save.
  - `BukuKasScreen`: net monthly balance, income/expense split, active due reminder strip, search & category/period filter, and transaction rows with reversal confirmation dialog.

- [ ] **Step 1: Write the failing widget tests for Quick-Add Numpad expense recording and Buku Kas balance update**

Create `F:\personal-finance\mobile\test\features\quick_add_and_buku_kas_widget_test.dart` verifying that tapping `+ Catat`, pressing `4`, `5`, `.000` on the custom numpad, selecting `Makan & Minum`, and tapping `Simpan` immediately renders `- Rp 45.000` in `BukuKasScreen` and increments the pending sync badge count while offline.

- [ ] **Step 2: Run widget test to verify it fails**

Run: `flutter test test/features/quick_add_and_buku_kas_widget_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `SwissLedgerTheme`, `LoginScreen`, `MainShellScreen`, `QuickAddTransactionSheet`, and `BukuKasScreen`**

Enforce `design-taste-frontend` rules across all widgets: `1px` hairline borders (`#E5E4DF`), zero emojis, zero em-dashes, `PhosphorIcon` glyphs only, and `FontFeature.tabularFigures()` on every Rupiah amount.

- [ ] **Step 4: Run widget test to verify it passes**

Run: `flutter test test/features/quick_add_and_buku_kas_widget_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib mobile/test/features/quick_add_and_buku_kas_widget_test.dart
git commit -m "feat(mobile): add Swiss Ledger theme, 5-point shell, quick-add numpad sheet, and Buku Kas screen"
```

---

### Task 7: Mobile UI — Kewajiban (Debts & 7-Term Installments), Wishlist, Reminders, Offline PDF Report & Backup

**Files:**
- Create: `F:\personal-finance\mobile\lib\features\debts\presentation\kewajiban_screen.dart`
- Create: `F:\personal-finance\mobile\lib\features\wishlist\presentation\wishlist_screen.dart`
- Create: `F:\personal-finance\mobile\lib\features\reports\data\pdf_report_generator.dart`
- Create: `F:\personal-finance\mobile\lib\features\reports\data\backup_export_service.dart`
- Create: `F:\personal-finance\mobile\lib\features\reports\presentation\reports_and_more_screen.dart`
- Create: `F:\personal-finance\server\app\Console\Commands\BackupFinanceDatabaseCommand.php`
- Test: `F:\personal-finance\mobile\test\features\kewajiban_wishlist_pdf_test.dart`

**Interfaces:**
- Consumes: Repositories, calculators, and `MainShellScreen` from Tasks 4, 5, and 6.
- Produces:
  - `KewajibanScreen`:
    - **Hutang & Piutang tab:** create debt/receivable, view remaining balance & derived status (`Lunas`, `Terlambat`, `Jatuh Tempo Hari Ini`, `Aktif`), view payment history, record partial/full payment (`record_debt_payment`), reverse payment, and archive.
    - **Cicilan tab:** create installment plan (with live preview of generated terms and last-term rounding before confirmation, including 7 monthly installments), segmented progress bar per term, record per-term payment (`record_installment_payment`), and payment history.
  - `WishlistScreen`: create/edit/archive wishlist items with `target_price`, `target_date`, priority (`Rendah`, `Sedang`, `Tinggi`), and status (`Direncanakan`, `Sedang Ditabung`, `Dibeli`, `Dibatalkan`) without altering cash balance.
  - `ReportsAndMoreScreen`:
    - Period summary (income, expense, net, debt/installment payments) + **Offline PDF Report Generator** (`PdfReportGenerator.generatePeriodReport(...)` returning non-empty PDF bytes directly from local SQLite data).
    - Full **Pengingat Jatuh Tempo** view grouped by `Terlambat`, `Hari Ini`, and `Mendatang`.
    - **Ekspor Data Backup** (`BackupExportService.exportJsonBackup(...)`), **Resolusi Konflik Sinkronisasi** (choose server state or re-apply local state), **Kelola Kategori**, optional **PIN Kunci Lokal**, and **Logout Aman** (warning dialog when `sync_outbox` has pending operations).
  - Server backup command: `php artisan finance:backup-db` creating a verifiable JSON/SQL snapshot for restore testing.

- [ ] **Step 1: Write the failing tests for 7-term installment UI/flow, wishlist isolation from cash balance, and offline PDF generation**

Create `F:\personal-finance\mobile\test\features\kewajiban_wishlist_pdf_test.dart` verifying:
1. Creating a 7-term installment plan of `Rp 6.000.000` generates 7 terms (`857142` x 6 + `857148`) and recording a partial payment on Term 1 updates remaining term balance and creates 1 expense transaction.
2. Adding and marking a Wishlist item as `purchased` (`Dibeli`) does NOT change the ledger cash balance in `BukuKasScreen`.
3. `PdfReportGenerator.generatePeriodReport(...)` produces valid `%PDF-` bytes offline from local Drift data containing the period header, totals, and transaction rows.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/kewajiban_wishlist_pdf_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement `KewajibanScreen`, `WishlistScreen`, `PdfReportGenerator`, `BackupExportService`, `ReportsAndMoreScreen`, and `BackupFinanceDatabaseCommand`**

Wire `KewajibanScreen`, `WishlistScreen`, and `ReportsAndMoreScreen` into `MainShellScreen`. Run `flutter analyze` and `flutter test` on `mobile/` and `php artisan test` on `server/`.

- [ ] **Step 4: Run all mobile and server tests to verify everything passes**

Run:
- `flutter test` (in `F:\personal-finance\mobile`)
- `flutter analyze` (in `F:\personal-finance\mobile`)
- `C:\xampp\php\php.exe artisan test` (in `F:\personal-finance\server`)
Expected: PASS with 0 analyzer errors and all tests green.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: complete obligaciones, 7-term installments, wishlist, reminders, offline PDF report, and backup tools"
```
