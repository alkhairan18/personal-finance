# Supabase Cloud Online Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable 24/7 PC-free online multi-user authentication and offline-first synchronization against Supabase Cloud (PostgreSQL + PostgREST RPC) while preserving dual-mode compatibility with the Laravel backend.

**Architecture:** We provision a complete PostgreSQL schema and `SECURITY DEFINER` RPC suite (`app_register`, `app_login`, `app_logout`, `sync_push`, `sync_pull`) in `supabase/schema.sql`, and upgrade `DioApiClient`, `AuthRepository`, and `LoginScreen` on Flutter mobile to route auth and sync operations to Supabase PostgREST RPC whenever a Supabase URL or Anon Key is configured.

**Tech Stack:** PostgreSQL 15+ (`pgcrypto`, PL/pgSQL RPCs, Row Level Security), Flutter 3.x (`Dio`, `Riverpod`, `FlutterSecureStorage`, `sqlite3`).

**Spec:** [`docs/superpowers/specs/2026-10-28-supabase-cloud-sync-design.md`](file:///F:/personal-finance/docs/superpowers/specs/2026-10-28-supabase-cloud-sync-design.md)

## Global Constraints

- All monetary values in PostgreSQL and Dart MUST be integer Rupiah (`BIGINT` / `int`), never floating-point.
- Every user's data is strictly isolated by `user_id` (`UUID`).
- `DioApiClient` must support both Supabase Cloud RPC mode (`/rest/v1/rpc/...`) and legacy Laravel API mode (`/api/v1/...`) seamlessly.
- All UI copy remains in Indonesian and adheres to the locked "Swiss Ledger" theme.

## Review Focus

1. **Missing `apikey` header when Supabase URL is entered without Anon Key:** `DioApiClient` must validate that `supabaseAnonKey` is non-empty when `isSupabaseUrl(baseUrl)` is true and throw a clear Indonesian `ApiValidationException('Supabase Anon Key wajib diisi untuk koneksi Supabase Cloud.')`.
2. **Idempotent replay on Supabase `sync_push`:** Sending the same `operation_id` twice to `public.sync_push` must return `"status": "replayed"` without duplicating transactions or double-deducting debt/installment balances.
3. **Version conflict detection in `public.sync_push`:** Pushing a stale `base_version` on a mutable entity (`wishlist`, `debt`, `installment_plan`, `category`) must return `"status": "conflict"` along with `"conflict_server_state"`.
4. **Persisting `supabaseAnonKey` across app restarts:** `AuthSession.toJson()` / `fromJson()` must persist `supabase_anon_key` in `FlutterSecureStorage` so background/startup auto-sync works after closing and reopening the app.
5. **Laravel PostgreSQL compatibility:** Provide `server/.env.supabase.example` so the Laravel server can also connect directly to Supabase's PostgreSQL pooler if desired.

---

### Task 1: Supabase PostgreSQL Schema, RLS Policies & Atomic Sync RPCs (`supabase/schema.sql`)

**Files:**
- Create: `F:\personal-finance\supabase\schema.sql`
- Create: `F:\personal-finance\supabase\PANDUAN_SUPABASE.md`
- Create: `F:\personal-finance\server\.env.supabase.example`
- Test: `F:\personal-finance\server\tests\Feature\Api\V1\SupabaseSchemaContractTest.php`

**Interfaces:**
- Produces PostgreSQL RPCs callable via PostgREST `POST /rest/v1/rpc/<name>`:
  - `public.app_register(p_name text, p_username text, p_password text, p_device_id uuid, p_device_name text) -> jsonb`
  - `public.app_login(p_username text, p_password text, p_device_id uuid, p_device_name text) -> jsonb`
  - `public.app_logout(p_token text) -> jsonb`
  - `public.sync_push(p_token text, p_device_id uuid, p_operations jsonb) -> jsonb`
  - `public.sync_pull(p_token text, p_cursor text, p_limit integer) -> jsonb`

- [ ] **Step 1: Write the failing contract test `SupabaseSchemaContractTest.php`**

```php
<?php

namespace Tests\Feature\Api\V1;

use Tests\TestCase;

class SupabaseSchemaContractTest extends TestCase
{
    public function test_supabase_schema_sql_defines_all_tables_rls_and_rpc_functions(): void
    {
        $sqlPath = base_path('../supabase/schema.sql');
        $this->assertFileExists($sqlPath);
        $sql = (string) file_get_contents($sqlPath);

        $this->assertStringContainsString('CREATE EXTENSION IF NOT EXISTS pgcrypto', $sql);
        $this->assertStringContainsString('CREATE TABLE IF NOT EXISTS public.app_users', $sql);
        $this->assertStringContainsString('CREATE TABLE IF NOT EXISTS public.financial_transactions', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.app_register(', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.app_login(', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.sync_push(', $sql);
        $this->assertStringContainsString('CREATE OR REPLACE FUNCTION public.sync_pull(', $sql);
        $this->assertStringContainsString('ENABLE ROW LEVEL SECURITY', $sql);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Set-Location F:\personal-finance\server; C:\xampp\php\php.exe vendor\bin\phpunit --filter SupabaseSchemaContractTest`
Expected: FAIL with "Failed asserting that file ... exists."

- [ ] **Step 3: Create `F:\personal-finance\supabase\schema.sql`, `F:\personal-finance\supabase\PANDUAN_SUPABASE.md`, and `F:\personal-finance\server\.env.supabase.example`**

Write the idempotent SQL script containing all tables (`app_users`, `app_devices`, `categories`, `financial_transactions`, `debts`, `debt_payments`, `installment_plans`, `installments`, `installment_payments`, `wishlists`, `sync_operations`, `sync_changes`), default system categories seed, RLS policies, and the 5 PL/pgSQL RPC functions (`app_register`, `app_login`, `app_logout`, `sync_push`, `sync_pull`), plus the Indonesian step-by-step guide `PANDUAN_SUPABASE.md`.

- [ ] **Step 4: Run test to verify it passes**

Run: `Set-Location F:\personal-finance\server; C:\xampp\php\php.exe vendor\bin\phpunit`
Expected: PASS (`23/23` tests passing).

- [ ] **Step 5: Commit**

```powershell
Set-Location F:\personal-finance; git add supabase/ server/; git commit -m "feat(supabase): add complete PostgreSQL schema, RLS, and PostgREST sync RPCs"
```

---

### Task 2: Mobile `DioApiClient` & `AuthRepository` Supabase Cloud RPC Support

**Files:**
- Modify: `F:\personal-finance\mobile\lib\core\network\api_client.dart`
- Modify: `F:\personal-finance\mobile\lib\features\auth\data\auth_repository.dart`
- Modify: `F:\personal-finance\mobile\lib\features\auth\presentation\login_screen.dart`
- Test: `F:\personal-finance\mobile\test\core\sync_engine_test.dart`
- Test: `F:\personal-finance\mobile\test\features\quick_add_and_buku_kas_widget_test.dart`

**Interfaces:**
- Produces on `DioApiClient`:
  - `static const String defaultSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '')`
  - `static const String defaultSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '')`
  - `static bool isSupabaseUrl(String url)`
  - `void setSupabaseAnonKey(String? anonKey)`
  - `String get supabaseAnonKey`
  - Automatic routing of `register`, `login`, `logoutRemote`, `pushOperations`, and `pullChanges` to `/rest/v1/rpc/...` with `apikey` and `Authorization: Bearer <anonKey>` headers when `isSupabaseMode` is active.
- Produces on `AuthSession` & `AuthRepository`:
  - `final String supabaseAnonKey` field persisted in `AuthSession.toJson()` / `fromJson()`.
  - `String? supabaseAnonKey` parameter on `AuthRepository.login(...)` and `AuthRepository.register(...)`.

- [ ] **Step 1: Write the failing tests in `sync_engine_test.dart` and `quick_add_and_buku_kas_widget_test.dart`**

```dart
test('DioApiClient routes auth and sync to Supabase PostgREST RPC when Supabase URL and Anon Key are configured', () async {
  expect(DioApiClient.isSupabaseUrl('https://xyzcompany.supabase.co'), isTrue);
  expect(DioApiClient.isSupabaseUrl('http://192.168.1.21:8000'), isFalse);

  final session = AuthSession(
    userId: 'u-1',
    username: 'budi',
    displayName: 'Budi',
    accessToken: 'supa-tok-1',
    deviceId: 'd-1',
    serverUrl: 'https://xyzcompany.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon',
  );
  final restored = AuthSession.fromJson(session.toJson());
  expect(restored.supabaseAnonKey, 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.anon');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat test test/core/sync_engine_test.dart --no-pub`
Expected: FAIL with "Member not found: 'DioApiClient.isSupabaseUrl'" and "No named parameter with the name 'supabaseAnonKey'".

- [ ] **Step 3: Implement Supabase RPC routing in `api_client.dart`, `auth_repository.dart`, and `login_screen.dart`**

Update `DioApiClient` to detect Supabase mode (`isSupabaseUrl(baseUrl) || _supabaseAnonKey.isNotEmpty`), validate that `_supabaseAnonKey` is provided when `isSupabaseUrl(baseUrl)` is true, and route `register` (`/rest/v1/rpc/app_register`), `login` (`/rest/v1/rpc/app_login`), `logoutRemote` (`/rest/v1/rpc/app_logout`), `pushOperations` (`/rest/v1/rpc/sync_push`), and `pullChanges` (`/rest/v1/rpc/sync_pull`). Add the `Supabase Anon Key (Opsional untuk Supabase Cloud)` field (`Key('login_supabase_anon_key_field')`) under `Pengaturan URL Server / Supabase Cloud` in `LoginScreen`.

- [ ] **Step 4: Run tests and analyzer to verify all pass**

Run: `Set-Location F:\personal-finance\mobile; F:\flutter\bin\flutter.bat test --no-pub; F:\flutter\bin\flutter.bat analyze --no-pub`
Expected: PASS (`22/22` tests passing, `No issues found!`).

- [ ] **Step 5: Commit and rebuild release APK**

```powershell
Set-Location F:\personal-finance; git add mobile/; git commit -m "feat(mobile): add Supabase Cloud PostgREST RPC sync and auth support"
```
