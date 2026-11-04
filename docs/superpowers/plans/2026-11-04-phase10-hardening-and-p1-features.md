# Phase 10: System Hardening, P0 Completion & P1 Financial Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden Supabase & mobile offline-first synchronization across all relational tables, complete all remaining P0 PRD user flows (obligation payment history, partial installment payments, wishlist target dates & filters, grouped reminders, category & profile management), and add P1 category budgeting and expense/payment-method analytics.

**Architecture:** Extends the SQLite `AppDatabase` (`local_budgets`, payment history queries, non-archived wishlist queries) and Supabase PostgreSQL RPC suite (`public.budgets`, `public.app_update_profile`, full relational upserts inside `public.sync_push`). Upgrades `SyncEngine` to unpack child installment terms on pull and automatically refresh expired tokens on `401`, then surfaces the new capabilities across `BukuKasScreen`, `KewajibanScreen`, `WishlistScreen`, `ReportsAndMoreScreen`, and `PdfReportGenerator`.

**Tech Stack:** Flutter (Dart, Riverpod, SQLite3 FFI, `pdf`, `printing`, `crypto`), Supabase PostgreSQL (`plpgsql` PostgREST RPCs), Laravel 11 (PHPUnit contract verification).

**Spec:** `docs/superpowers/specs/2026-11-04-phase10-hardening-and-p1-features-design.md`

## Global Constraints

- Keep the 5-point bottom navigation bar (`Buku Kas`, `Kewajiban`, `+ Catat`, `Wishlist`, `Laporan`) unchanged.
- All monetary values in SQLite, Dart, and PostgreSQL must remain exact integers in Rupiah (`INTEGER` / `bigint`, `> 0`).
- Deterministic budget UUID formula: `sha256('pf-budget-v1:$userId:$categoryId:$periodMonth')` formatted as a UUID (`8-4-4-4-12` with version nibble `4` and variant nibble `8`).
- Budget threshold colors: `< 80%` `SwissLedgerColors.accentTeal`, `80%–99%` `SwissLedgerColors.warningAmber`, `>= 100%` `SwissLedgerColors.dangerRed`.
- Never commit sensitive credentials or Supabase keys to Git.

## Review Focus

- Setting a budget twice for the same `(userId, categoryId, periodMonth)` must update the existing row and increment `version` rather than creating duplicate rows.
- Pulling an `installment_plan` payload that contains an `installments` list must populate `local_installments` on the receiving device so terms are immediately visible and payable.
- Calling `SyncEngine.synchronize()` when the token is expired (`401 UNAUTHENTICATED`) must invoke `onRefreshAuth` once and succeed on retry without losing pending outbox items.
- Restoring a JSON backup with `enqueueForSync: true` must queue restored entities in `sync_outbox` so a newly restored phone pushes them to the cloud on the next sync.
- Generating a PDF report when transaction titles or notes contain emojis or non-ASCII characters (e.g., `Makan 🍜 — Café`) must strip/normalize unsupported glyphs so Helvetica never throws or warns.

---

### Task 1: Supabase Schema & Relational Sync Hardening (`MOD-01` & `MOD-06`)

**Files:**
- Modify: `supabase/schema.sql`
- Modify: `server/tests/Feature/SupabaseSchemaContractTest.php`

**Interfaces:**
- Produces:
  - Table `public.budgets` with RLS policy `budgets_self`
  - RPC `public.app_update_profile(p_token text, p_name text, p_current_password text DEFAULT NULL, p_new_password text DEFAULT NULL) RETURNS jsonb`
  - Updated RPC `public.sync_push(p_token text, p_device_id uuid, p_operations jsonb)` writing relational rows to `public.categories`, `public.debts`, `public.debt_payments`, `public.installment_plans`, `public.installments`, `public.installment_payments`, and `public.budgets`

- [ ] **Step 1: Add contract assertions in `server/tests/Feature/SupabaseSchemaContractTest.php`**

Add assertions checking that `supabase/schema.sql` defines `CREATE TABLE IF NOT EXISTS public.budgets`, `CREATE OR REPLACE FUNCTION public.app_update_profile`, and relational `INSERT INTO public.debts`, `INSERT INTO public.installment_plans`, `INSERT INTO public.installments`, and `INSERT INTO public.budgets` inside `public.sync_push`.

- [ ] **Step 2: Run PHPUnit test to verify it fails**

Run: `Set-Location F:\personal-finance\server; C:\xampp\php\php.exe artisan test --filter=SupabaseSchemaContractTest`
Expected: FAIL because `public.budgets` and `public.app_update_profile` are not yet in `supabase/schema.sql`.

- [ ] **Step 3: Update `supabase/schema.sql` with `public.budgets`, `public.app_update_profile`, and relational branches in `public.sync_push`**

Implement `public.budgets` table + RLS, `public.app_update_profile` with `SET search_path = public, extensions`, and relational upserts/reversals for `category`, `debt`, `debt_payment`, `installment_plan`, `installment_payment`, and `budget` inside `public.sync_push`.

- [ ] **Step 4: Run PHPUnit test to verify it passes**

Run: `Set-Location F:\personal-finance\server; C:\xampp\php\php.exe artisan test`
Expected: PASS (`23/23` tests passing).

- [ ] **Step 5: Commit**

```powershell
Set-Location F:\personal-finance
git add supabase/schema.sql server/tests/Feature/SupabaseSchemaContractTest.php
git commit -m "feat(supabase): add budgets table, profile RPC, and full relational sync_push handlers"
```

---

### Task 2: Mobile Database, Repositories, Auto Re-Auth & Sync Engine Hardening (`MOD-01` – `MOD-05` Data Layer)

**Files:**
- Modify: `mobile/lib/core/database/app_database.dart`
- Create: `mobile/lib/features/budgets/data/budget_repository.dart`
- Modify: `mobile/lib/features/transactions/data/transaction_repository.dart`
- Modify: `mobile/lib/features/wishlist/data/wishlist_repository.dart`
- Modify: `mobile/lib/core/network/api_client.dart`
- Modify: `mobile/lib/features/auth/data/auth_repository.dart`
- Modify: `mobile/lib/core/sync/sync_engine.dart`
- Modify: `mobile/lib/features/reports/data/backup_export_service.dart`
- Modify: `mobile/test/core/offline_repository_outbox_test.dart`
- Modify: `mobile/test/core/sync_engine_test.dart`

**Interfaces:**
- Produces:
  - `LocalBudget` model & `AppDatabase.getActiveBudgets({required String periodMonth})`, `getPaymentsForDebt(String debtId)`, `getPaymentsForPlan(String planId)`, `getAllNonArchivedWishlistItems()`
  - `BudgetRepository.deterministicBudgetId({required String userId, required String categoryId, required String periodMonth})`
  - `BudgetRepository.upsertBudget({required String categoryId, required String periodMonth, required int limitAmount}) -> Future<String>`
  - `BudgetRepository.archiveBudget(String budgetId) -> Future<void>`
  - `TransactionRepository.updateCategory({required String categoryId, required String name, String? iconKey})` & `archiveCategory(String categoryId)`
  - `WishlistRepository.createWishlistItem(..., {String? targetDate, String? notes, String? urlOrReference})` & `updateWishlistItem(..., {String? targetDate, String? notes, String? urlOrReference, String? status})`
  - `AuthRepository.forceRefreshOnlineToken() -> Future<bool>` & `AuthRepository.updateProfile({required String displayName, String? currentPassword, String? newPassword}) -> Future<void>`
  - `SyncEngine({..., Future<bool> Function()? onRefreshAuth})`
  - `BackupExportService.restoreFromJsonString(AppDatabase db, String jsonStr, {bool enqueueForSync = true})`

- [ ] **Step 1: Write failing unit tests in `mobile/test/core/offline_repository_outbox_test.dart` and `mobile/test/core/sync_engine_test.dart`**

Add tests for:
1. `BudgetRepository.upsertBudget` deterministic ID idempotency (updating same category + month updates existing budget and increments `version`).
2. `SyncEngine` pulling an `installment_plan` with nested `installments` populates `local_installments`.
3. `SyncEngine` receiving a `401 UNAUTHENTICATED` `ApiValidationException` calls `onRefreshAuth` once and retries push/pull to completion.
4. `BackupExportService.restoreFromJsonString` with `enqueueForSync: true` restores `budgets` and queues restored records in `sync_outbox`.

- [ ] **Step 2: Run Flutter unit tests to verify they fail**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat test test/core/offline_repository_outbox_test.dart test/core/sync_engine_test.dart --no-pub`
Expected: FAIL with missing `BudgetRepository`, `onRefreshAuth`, and `local_budgets`.

- [ ] **Step 3: Implement `AppDatabase`, `BudgetRepository`, `TransactionRepository`, `WishlistRepository`, `AuthRepository`, `SyncEngine`, and `BackupExportService` updates**

Implement the schema, repository methods, `SyncEngine` nested installment unpacking + `budget` sync + `401` retry via `onRefreshAuth`, and sync-aware JSON restore.

- [ ] **Step 4: Run Flutter unit tests to verify they pass**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat test test/core/offline_repository_outbox_test.dart test/core/sync_engine_test.dart --no-pub`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
Set-Location F:\personal-finance
git add mobile/lib mobile/test/core
git commit -m "feat(mobile-core): add budgets, payment history queries, 401 auto-reauth, and nested installment pull"
```

---

### Task 3: Mobile UI — Buku Kas Budgets, Kewajiban Payment History & Partial Installment Payments, and Wishlist Filters (`MOD-03`, `MOD-04`, `MOD-05`)

**Files:**
- Modify: `mobile/lib/app/providers/app_providers.dart`
- Modify: `mobile/lib/features/dashboard/presentation/buku_kas_screen.dart`
- Modify: `mobile/lib/features/debts/presentation/kewajiban_screen.dart`
- Modify: `mobile/lib/features/wishlist/presentation/wishlist_screen.dart`
- Modify: `mobile/test/features/kewajiban_wishlist_pdf_test.dart`

**Interfaces:**
- Consumes: `BudgetRepository`, `AppDatabase.getActiveBudgets`, `AppDatabase.getPaymentsForDebt`, `AppDatabase.getPaymentsForPlan`, `AppDatabase.getAllNonArchivedWishlistItems`
- Produces:
  - `budgetRepositoryProvider` in `app_providers.dart`
  - **Anggaran Kategori Bulan Ini** card & **Atur Anggaran** dialog (`Key('manage_budgets_button')`) in `BukuKasScreen`
  - **Bayar Termin Cicilan** partial-payment + date-picker dialog & **Riwayat Pembayaran** sheet in `KewajibanScreen`
  - Target date, notes, `Dibatalkan` status, and filter chips (`Semua`, `Aktif`, `Prioritas Tinggi`, `Dibeli`, `Dibatalkan`) in `WishlistScreen`

- [ ] **Step 1: Add widget tests in `mobile/test/features/kewajiban_wishlist_pdf_test.dart` for partial installment payment and wishlist filter chips**

Verify that a partial installment payment updates `paidAmount` and `remainingAmount` accurately and that `WishlistScreen` filter chips (`Dibeli`, `Aktif`) filter displayed items.

- [ ] **Step 2: Run widget test to verify new assertions fail**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat test test/features/kewajiban_wishlist_pdf_test.dart --no-pub`
Expected: FAIL.

- [ ] **Step 3: Implement UI upgrades in `app_providers.dart`, `buku_kas_screen.dart`, `kewajiban_screen.dart`, and `wishlist_screen.dart`**

Wire `budgetRepositoryProvider` and `onRefreshAuth`, build the budget progress section in `BukuKasScreen`, add payment history sheets & partial installment payment dialog in `KewajibanScreen`, and add target date / notes / filter chips in `WishlistScreen`.

- [ ] **Step 4: Run widget tests to verify they pass**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat test test/features/kewajiban_wishlist_pdf_test.dart --no-pub`
Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
Set-Location F:\personal-finance
git add mobile/lib mobile/test/features/kewajiban_wishlist_pdf_test.dart
git commit -m "feat(mobile-ui): add category budgets, obligation payment history, partial installment pay, and wishlist filters"
```

---

### Task 4: Mobile UI — Analytics Card, Grouped Reminders, Category & Profile Management, and Unicode-Safe PDF Report (`MOD-05` & `MOD-06`)

**Files:**
- Modify: `mobile/lib/features/reports/data/pdf_report_generator.dart`
- Modify: `mobile/lib/features/reports/presentation/reports_and_more_screen.dart`
- Modify: `mobile/test/features/kewajiban_wishlist_pdf_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.getActiveBudgets`, `TransactionRepository.updateCategory` / `archiveCategory`, `AuthRepository.updateProfile`
- Produces:
  - Unicode-safe `PdfReportGenerator.generatePeriodReport` with receivable summary, installment summary, and category/budget breakdown table
  - **Analitik Pengeluaran & Metode Pembayaran** card, grouped reminders (**Terlambat**, **Hari Ini**, **Mendatang**), **Kelola Kategori** dialog (`Key('manage_categories_button')`), and **Pengaturan Profil & Kata Sandi** dialog (`Key('manage_profile_button')`) in `ReportsAndMoreScreen`

- [ ] **Step 1: Add PDF Unicode & budget/category table test in `mobile/test/features/kewajiban_wishlist_pdf_test.dart`**

Add a transaction containing emoji (`Makan Siang 🍜`) and a category budget, call `PdfReportGenerator.generatePeriodReport`, and assert valid `%PDF-` output with zero Helvetica Unicode warnings.

- [ ] **Step 2: Run test to verify behavior**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat test test/features/kewajiban_wishlist_pdf_test.dart --no-pub`

- [ ] **Step 3: Implement `PdfReportGenerator` and `ReportsAndMoreScreen` upgrades**

Add `_sanitizePdfText` and category/receivable/installment tables in `PdfReportGenerator`, and add the analytics breakdown card, 3-tier grouped reminders, category manager dialog, and profile/password dialog in `ReportsAndMoreScreen`.

- [ ] **Step 4: Run full test & analyzer suites across Mobile and Server**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat analyze --no-pub; F:\flutter\bin\flutter.bat test --no-pub`
Expected: `No issues found!` and all tests passing.

- [ ] **Step 5: Commit, Push to GitHub, and Rebuild Signed Release APK**

```powershell
Set-Location F:\personal-finance
git add mobile/lib mobile/test
git commit -m "feat(reports): add expense analytics, grouped reminders, category/profile management, and enhanced PDF"
git push origin main
```
