# Supabase Cloud Online Database & Sync Design ("Buku Kas Pribadi")

**Date:** 2026-10-28  
**Status:** Approved for Planning  
**Target:** `F:\personal-finance\supabase\` and `F:\personal-finance\mobile\`

## 1. Intent & Why

Previously, online synchronization required running a local Laravel server (`php artisan serve`) on the user's PC over the same Wi-Fi LAN (`http://192.168.1.x:8000`). Whenever the PC was turned off or the Wi-Fi router assigned a new local IP, mobile devices could not synchronize.

By migrating the online database and sync backend to **Supabase Cloud (PostgreSQL + PostgREST RPC)**:
1. **Zero PC Dependency:** Mobile devices synchronize 24/7 from anywhere (Wi-Fi or cellular data) against a permanent HTTPS URL (`https://<project-ref>.supabase.co`).
2. **One-Paste Setup:** Running a single SQL script (`supabase/schema.sql`) in the Supabase SQL Editor provisions all tables, indexes, `pgcrypto` password hashing, token verification, and atomic `sync_push` / `sync_pull` RPC functions.
3. **Multi-User Isolation:** Every user account has a deterministic UUID and strict `user_id` isolation on both local SQLite and Supabase PostgreSQL.
4. **Dual-Backend Compatibility:** `DioApiClient` automatically detects Supabase Cloud mode (when a `.supabase.co` URL or `SUPABASE_ANON_KEY` is configured) while preserving compatibility with the existing Laravel API endpoints (`/api/v1/...`).

## 2. Goals & Non-Goals

### Goals
- Complete, idempotent PostgreSQL schema and RPC script (`supabase/schema.sql`) for Supabase SQL Editor.
- Atomic PostgreSQL RPC endpoints:
  - `POST /rest/v1/rpc/app_register`
  - `POST /rest/v1/rpc/app_login`
  - `POST /rest/v1/rpc/app_logout`
  - `POST /rest/v1/rpc/sync_push`
  - `POST /rest/v1/rpc/sync_pull`
- Mobile `DioApiClient` support for `SUPABASE_URL` and `SUPABASE_ANON_KEY` (via `--dart-define` defaults and runtime configuration on `LoginScreen`).
- ClearIndonesian setup guide (`supabase/PANDUAN_SUPABASE.md`) for pasting `schema.sql` and obtaining `Project URL` + `anon public key`.

### Non-Goals
- Removing offline-first SQLite storage on Android (the app remains 100% offline-first; Supabase is the cloud sync & backup store).
- Rewriting the UI theme (retains the locked "Swiss Ledger" aesthetic).

## 3. Architecture & Data Flow

1. **Local-First SQLite (`AppDatabase`)**: All UI reads and writes happen in `< 50ms` against local SQLite (`local_transactions`, `local_debts`, `local_installments`, `local_wishlist`, `local_categories`) and enqueue mutations in `sync_outbox`.
2. **Transport Layer (`DioApiClient`)**:
   - Detects `isSupabaseMode` when `baseUrl.contains('.supabase.co')` or `supabaseAnonKey.isNotEmpty`.
   - Attaches `apikey: <supabaseAnonKey>` and `Authorization: Bearer < supabaseAnonKey >` on PostgREST RPC calls, passing the user's session token (`p_token`) inside the JSON RPC body so custom session tokens work without requiring Supabase Auth email confirmation toggles.
3. **Cloud Database (`supabase/schema.sql`)**:
   - Uses `pgcrypto` (`crypt`, `gen_salt('bf')`, `gen_random_bytes`) to hash passwords and issue 30-day session tokens in `public.app_devices`.
   - `public.sync_push(p_token, p_device_id, p_operations)` validates the session token, iterates operations idempotently via `public.sync_operations`, applies upserts/payments/reversals/archives, and appends to `public.sync_changes` with monotonic `id BIGSERIAL`.
   - `public.sync_pull(p_token, p_cursor, p_limit)` validates the session token and returns cursor-paginated `sync_changes` for that `user_id`.
