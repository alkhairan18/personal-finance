-- =============================================================================
-- BUKU KAS PRIBADI — SUPABASE CLOUD SCHEMA, RLS & POSTGREST SYNC RPC SUITE
-- =============================================================================
-- Cara pakai:
-- 1. Buka dashboard Supabase (https://supabase.com/dashboard) -> pilih Project Anda.
-- 2. Buka menu "SQL Editor" -> klik "New query".
-- 3. Copy-paste seluruh isi file ini lalu klik tombol "Run".
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Helper: Deterministic User UUID (100% identik dengan aplikasi Mobile & Laravel)
CREATE OR REPLACE FUNCTION public.deterministic_user_id(p_username text)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_clean text := lower(trim(p_username));
  v_hex text;
BEGIN
  IF v_clean = 'anzhel' THEN
    RETURN '22222222-2222-4222-8222-000000000001'::uuid;
  ELSIF v_clean = 'wina' THEN
    RETURN '22222222-2222-4222-8222-000000000002'::uuid;
  END IF;

  v_hex := encode(digest('pf-user-id-v1:' || v_clean, 'sha256'), 'hex');
  RETURN (
    substr(v_hex, 1, 8) || '-' ||
    substr(v_hex, 9, 4) || '-4' ||
    substr(v_hex, 14, 3) || '-8' ||
    substr(v_hex, 18, 3) || '-' ||
    substr(v_hex, 21, 12)
  )::uuid;
END;
$$;

-- 2. Tables
CREATE TABLE IF NOT EXISTS public.app_users (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.app_devices (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  device_name text NOT NULL DEFAULT 'Android Pribadi',
  token_hash text UNIQUE,
  expires_at timestamptz,
  revoked_at timestamptz,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.categories (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES public.app_users(id) ON DELETE CASCADE,
  name text NOT NULL,
  type text NOT NULL CHECK (type IN ('income', 'expense')),
  icon_key text NOT NULL DEFAULT 'receipt',
  is_system boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 1,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.financial_transactions (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  type text NOT NULL CHECK (type IN ('income', 'expense')),
  amount_minor bigint NOT NULL CHECK (amount_minor > 0),
  transaction_date date NOT NULL,
  category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  payment_method text,
  note text,
  source_type text,
  source_id uuid,
  status text NOT NULL DEFAULT 'posted' CHECK (status IN ('posted', 'reversed')),
  reversed_by_transaction_id uuid,
  reverses_transaction_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.debts (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  direction text NOT NULL CHECK (direction IN ('payable', 'receivable')),
  counterparty text NOT NULL,
  principal_amount bigint NOT NULL CHECK (principal_amount > 0),
  start_date date NOT NULL,
  due_date date,
  category text,
  note text,
  status text NOT NULL DEFAULT 'active',
  version integer NOT NULL DEFAULT 1,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.debt_payments (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  debt_id uuid NOT NULL REFERENCES public.debts(id) ON DELETE CASCADE,
  transaction_id uuid REFERENCES public.financial_transactions(id) ON DELETE SET NULL,
  amount bigint NOT NULL CHECK (amount > 0),
  paid_at date NOT NULL,
  note text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'reversed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.installment_plans (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  title text NOT NULL,
  vendor text,
  total_amount bigint NOT NULL CHECK (total_amount > 0),
  installment_count integer NOT NULL CHECK (installment_count > 0),
  frequency text NOT NULL DEFAULT 'monthly',
  start_date date NOT NULL,
  Payment_method text,
  note text,
  status text NOT NULL DEFAULT 'active',
  version integer NOT NULL DEFAULT 1,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.installments (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  installment_plan_id uuid NOT NULL REFERENCES public.installment_plans(id) ON DELETE CASCADE,
  sequence_no integer NOT NULL,
  due_date date NOT NULL,
  amount bigint NOT NULL CHECK (amount > 0),
  paid_amount bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  paid_at timestamptz,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.installment_payments (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  installment_id uuid NOT NULL REFERENCES public.installments(id) ON DELETE CASCADE,
  transaction_id uuid REFERENCES public.financial_transactions(id) ON DELETE SET NULL,
  amount bigint NOT NULL CHECK (amount > 0),
  paid_at date NOT NULL,
  note text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'reversed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.wishlists (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  title text NOT NULL,
  target_price bigint NOT NULL CHECK (target_price > 0),
  saved_amount bigint NOT NULL DEFAULT 0 CHECK (saved_amount >= 0),
  target_date date,
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  category text,
  icon_key text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'saving', 'purchased', 'cancelled')),
  note text,
  version integer NOT NULL DEFAULT 1,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sync_operations (
  operation_id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  device_id uuid NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  action text NOT NULL,
  response_snapshot jsonb NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.sync_changes (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.app_users(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  entity_version integer NOT NULL DEFAULT 1,
  operation text NOT NULL CHECK (operation IN ('upsert', 'tombstone')),
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sync_changes_user_id_id ON public.sync_changes(user_id, id);

-- 3. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debt_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.installment_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sync_changes ENABLE ROW LEVEL SECURITY;

-- 4. Seed Default System Categories & Default Accounts (Anzhel & Wina)
INSERT INTO public.categories (id, user_id, name, type, icon_key, is_system) VALUES
  ('00000000-0000-4000-8000-000000000001', NULL, 'Makan & Minum', 'expense', 'fork-knife', true),
  ('00000000-0000-4000-8000-000000000002', NULL, 'Transportasi', 'expense', 'car-simple', true),
  ('00000000-0000-4000-8000-000000000003', NULL, 'Kebutuhan Rumah', 'expense', 'house-line', true),
  ('00000000-0000-4000-8000-000000000004', NULL, 'Tagihan & Utilitas', 'expense', 'lightning', true),
  ('00000000-0000-4000-8000-000000000005', NULL, 'Cicilan', 'expense', 'calendar-check', true),
  ('00000000-0000-4000-8000-000000000006', NULL, 'Kesehatan', 'expense', 'first-aid-kit', true),
  ('00000000-0000-4000-8000-000000000007', NULL, 'Hiburan', 'expense', 'film-slate', true),
  ('00000000-0000-4000-8000-000000000008', NULL, 'Belanja Pribadi', 'expense', 'shopping-bag', true),
  ('00000000-0000-4000-8000-000000000009', NULL, 'Gaji', 'income', 'wallet', true),
  ('00000000-0000-4000-8000-000000000010', NULL, 'Bonus / THR', 'income', 'coins', true),
  ('00000000-0000-4000-8000-000000000011', NULL, 'Usaha / Freelance', 'income', 'briefcase', true),
  ('00000000-0000-4000-8000-000000000012', NULL, 'Pemasukan Lainnya', 'income', 'arrow-down-left', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.app_users (id, name, username, password_hash, is_active) VALUES
  ('22222222-2222-4222-8222-000000000001', 'Anzhel', 'anzhel', crypt('PasswordKuatAnzhel123!', gen_salt('bf')), true),
  ('22222222-2222-4222-8222-000000000002', 'Wina', 'wina', crypt('PasswordKuatWina123!', gen_salt('bf')), true)
ON CONFLICT (username) DO NOTHING;

-- 5. Token verification helper
CREATE OR REPLACE FUNCTION public.verify_app_token(p_token text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hash text;
  v_user_id uuid;
BEGIN
  IF p_token IS NULL OR trim(p_token) = '' THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Token sesi tidak ditemukan.';
  END IF;

  v_hash := encode(digest(trim(p_token), 'sha256'), 'hex');
  SELECT d.user_id INTO v_user_id
  FROM public.app_devices d
  JOIN public.app_users u ON u.id = d.user_id
  WHERE d.token_hash = v_hash
    AND d.revoked_at IS NULL
    AND (d.expires_at IS NULL OR d.expires_at > now())
    AND u.is_active = true
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Sesi telah berakhir atau tidak valid.';
  END IF;

  UPDATE public.app_devices SET last_seen_at = now() WHERE token_hash = v_hash;
  RETURN v_user_id;
END;
$$;

-- 6. RPC: Register Any New User
CREATE OR REPLACE FUNCTION public.app_register(
  p_name text,
  p_username text,
  p_password text,
  p_device_id uuid,
  p_device_name text DEFAULT 'Android Pribadi'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text := lower(trim(coalesce(p_username, '')));
  v_name text := trim(coalesce(p_name, ''));
  v_user_id uuid;
  v_raw_token text;
  v_token_hash text;
  v_expires timestamptz := now() + interval '30 days';
BEGIN
  IF v_name = '' OR length(v_username) < 3 OR length(coalesce(p_password, '')) < 8 THEN
    RAISE EXCEPTION 'VALIDATION_ERROR: Nama, username (min 3 karakter), dan kata sandi (min 8 karakter) wajib diisi.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.app_users WHERE username = v_username) THEN
    RAISE EXCEPTION 'VALIDATION_ERROR: Username sudah digunakan oleh akun lain.';
  END IF;

  v_user_id := public.deterministic_user_id(v_username);
  INSERT INTO public.app_users (id, name, username, password_hash, is_active)
  VALUES (v_user_id, v_name, v_username, crypt(p_password, gen_salt('bf')), true);

  v_raw_token := encode(gen_random_bytes(32), 'hex');
  v_token_hash := encode(digest(v_raw_token, 'sha256'), 'hex');

  INSERT INTO public.app_devices (id, user_id, device_name, token_hash, expires_at, revoked_at, last_seen_at)
  VALUES (p_device_id, v_user_id, coalesce(p_device_name, 'Android Pribadi'), v_token_hash, v_expires, NULL, now())
  ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    device_name = EXCLUDED.device_name,
    token_hash = EXCLUDED.token_hash,
    expires_at = EXCLUDED.expires_at,
    revoked_at = NULL,
    last_seen_at = now();

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'token', v_raw_token,
      'token_type', 'Bearer',
      'expires_at', to_char(v_expires AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'user', jsonb_build_object(
        'id', v_user_id,
        'name', v_name,
        'username', v_username
      )
    )
  );
END;
$$;

-- 7. RPC: Login User
CREATE OR REPLACE FUNCTION public.app_login(
  p_username text,
  p_password text,
  p_device_id uuid,
  p_device_name text DEFAULT 'Android Pribadi'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_username text := lower(trim(coalesce(p_username, '')));
  v_user public.app_users%ROWTYPE;
  v_raw_token text;
  v_token_hash text;
  v_expires timestamptz := now() + interval '30 days';
BEGIN
  SELECT * INTO v_user
  FROM public.app_users
  WHERE username = v_username AND is_active = true
  LIMIT 1;

  IF v_user.id IS NULL OR v_user.password_hash != crypt(p_password, v_user.password_hash) THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: Username atau kata sandi tidak sesuai.';
  END IF;

  v_raw_token := encode(gen_random_bytes(32), 'hex');
  v_token_hash := encode(digest(v_raw_token, 'sha256'), 'hex');

  INSERT INTO public.app_devices (id, user_id, device_name, token_hash, expires_at, revoked_at, last_seen_at)
  VALUES (p_device_id, v_user.id, coalesce(p_device_name, 'Android Pribadi'), v_token_hash, v_expires, NULL, now())
  ON CONFLICT (id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    device_name = EXCLUDED.device_name,
    token_hash = EXCLUDED.token_hash,
    expires_at = EXCLUDED.expires_at,
    revoked_at = NULL,
    last_seen_at = now();

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'token', v_raw_token,
      'token_type', 'Bearer',
      'expires_at', to_char(v_expires AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'user', jsonb_build_object(
        'id', v_user.id,
        'name', v_user.name,
        'username', v_user.username
      )
    )
  );
END;
$$;

-- 8. RPC: Logout User
CREATE OR REPLACE FUNCTION public.app_logout(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hash text := encode(digest(trim(coalesce(p_token, '')), 'sha256'), 'hex');
BEGIN
  UPDATE public.app_devices
  SET revoked_at = now(), token_hash = NULL
  WHERE token_hash = v_hash;

  RETURN jsonb_build_object('data', jsonb_build_object('logged_out', true));
END;
$$;

-- 9. RPC: Atomic Idempotent Sync Push
CREATE OR REPLACE FUNCTION public.sync_push(
  p_token text,
  p_device_id uuid,
  p_operations jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_op jsonb;
  v_op_id uuid;
  v_entity_type text;
  v_entity_id uuid;
  v_action text;
  v_base_version integer;
  v_payload jsonb;
  v_existing_op public.sync_operations%ROWTYPE;
  v_results jsonb := '[]'::jsonb;
  v_result_entry jsonb;
  v_new_version integer;
  v_cursor bigint;
  v_tx_id uuid;
  v_reversal_id uuid;
  v_orig_tx public.financial_transactions%ROWTYPE;
  v_debt public.debts%ROWTYPE;
  v_wl public.wishlists%ROWTYPE;
BEGIN
  v_user_id := public.verify_app_token(p_token);

  FOR v_op IN SELECT * FROM jsonb_array_elements(coalesce(p_operations, '[]'::jsonb))
  LOOP
    v_op_id := (v_op->>'operation_id')::uuid;
    v_entity_type := coalesce(v_op->>'entity_type', '');
    v_entity_id := (v_op->>'entity_id')::uuid;
    v_action := coalesce(v_op->>'action', v_op->>'operation', 'upsert');
    v_base_version := (v_op->>'base_version')::integer;
    v_payload := coalesce(v_op->'payload', '{}'::jsonb);

    SELECT * INTO v_existing_op FROM public.sync_operations WHERE operation_id = v_op_id;
    IF FOUND THEN
      v_result_entry := jsonb_set(v_existing_op.response_snapshot, '{status}', '"replayed"');
      v_results := v_results || jsonb_build_array(v_result_entry);
      CONTINUE;
    END IF;

    v_new_version := coalesce(v_base_version, 0) + 1;

    IF v_action = 'upsert' AND v_entity_type IN ('financial_transaction', 'transaction') THEN
      INSERT INTO public.financial_transactions (
        id, user_id, type, amount_minor, transaction_date, category_id, payment_method, note, status
      ) VALUES (
        v_entity_id,
        v_user_id,
        coalesce(v_payload->>'type', 'expense'),
        coalesce((v_payload->>'amount_minor')::bigint, (v_payload->>'amount')::bigint, 1),
        coalesce((v_payload->>'transaction_date')::date, current_date),
        NULLIF(v_payload->>'category_id', '')::uuid,
        v_payload->>'payment_method',
        coalesce(v_payload->>'note', v_payload->>'title', v_payload->>'notes'),
        'posted'
      )
      ON CONFLICT (id) DO UPDATE SET
        type = EXCLUDED.type,
        amount_minor = EXCLUDED.amount_minor,
        transaction_date = EXCLUDED.transaction_date,
        category_id = EXCLUDED.category_id,
        payment_method = EXCLUDED.payment_method,
        note = EXCLUDED.note,
        updated_at = now()
      WHERE public.financial_transactions.user_id = v_user_id;

      INSERT INTO public.sync_changes (user_id, entity_type, entity_id, entity_version, operation, payload)
      VALUES (v_user_id, 'financial_transaction', v_entity_id, v_new_version, 'upsert', v_payload || jsonb_build_object('id', v_entity_id, 'user_id', v_user_id, 'status', 'posted'));

    ELSIF v_action = 'reverse_transaction' THEN
      SELECT * INTO v_orig_tx FROM public.financial_transactions WHERE id = v_entity_id AND user_id = v_user_id;
      IF FOUND AND v_orig_tx.status = 'posted' THEN
        v_reversal_id := coalesce(NULLIF(v_payload->>'reversal_transaction_id', '')::uuid, gen_random_uuid());
        UPDATE public.financial_transactions SET status = 'reversed', reversed_by_transaction_id = v_reversal_id, updated_at = now() WHERE id = v_entity_id;
        INSERT INTO public.financial_transactions (
          id, user_id, type, amount_minor, transaction_date, category_id, note, source_type, status, reverses_transaction_id
        ) VALUES (
          v_reversal_id,
          v_user_id,
          CASE WHEN v_orig_tx.type = 'expense' THEN 'income' ELSE 'expense' END,
          v_orig_tx.amount_minor,
          coalesce((v_payload->>'reversal_date')::date, current_date),
          v_orig_tx.category_id,
          coalesce(v_payload->>'reason', 'Koreksi Transaksi'),
          'reversal',
          'posted',
          v_entity_id
        ) ON CONFLICT (id) DO NOTHING;

        INSERT INTO public.sync_changes (user_id, entity_type, entity_id, entity_version, operation, payload)
        VALUES (v_user_id, 'financial_transaction', v_entity_id, 2, 'upsert', jsonb_build_object(
          'id', v_entity_id, 'user_id', v_user_id, 'type', v_orig_tx.type, 'amount_minor', v_orig_tx.amount_minor,
          'transaction_date', v_orig_tx.transaction_date, 'status', 'reversed'
        ));
      END IF;

    ELSIF v_action = 'upsert' AND v_entity_type = 'wishlist' THEN
      SELECT * INTO v_wl FROM public.wishlists WHERE id = v_entity_id;
      IF FOUND AND v_wl.user_id = v_user_id AND v_base_version IS NOT NULL AND v_wl.version != v_base_version THEN
        v_result_entry := jsonb_build_object(
          'operation_id', v_op_id,
          'entity_type', 'wishlist',
          'entity_id', v_entity_id,
          'status', 'conflict',
          'entity_version', v_wl.version,
          'conflict_server_state', to_jsonb(v_wl)
        );
        v_results := v_results || jsonb_build_array(v_result_entry);
        CONTINUE;
      END IF;

      v_new_version := CASE WHEN FOUND THEN v_wl.version + 1 ELSE 1 END;
      INSERT INTO public.wishlists (
        id, user_id, title, target_price, saved_amount, target_date, priority, category, icon_key, status, note, version
      ) VALUES (
        v_entity_id,
        v_user_id,
        coalesce(v_payload->>'title', v_payload->>'item_name', 'Wishlist'),
        coalesce((v_payload->>'target_price')::bigint, (v_payload->>'target_amount')::bigint, 1),
        coalesce((v_payload->>'saved_amount')::bigint, 0),
        NULLIF(v_payload->>'target_date', '')::date,
        coalesce(v_payload->>'priority', 'medium'),
        v_payload->>'category',
        v_payload->>'icon_key',
        coalesce(v_payload->>'status', 'planned'),
        v_payload->>'note',
        v_new_version
      )
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        target_price = EXCLUDED.target_price,
        saved_amount = EXCLUDED.saved_amount,
        target_date = EXCLUDED.target_date,
        priority = EXCLUDED.priority,
        status = EXCLUDED.status,
        note = EXCLUDED.note,
        version = EXCLUDED.version,
        updated_at = now()
      WHERE public.wishlists.user_id = v_user_id;

      INSERT INTO public.sync_changes (user_id, entity_type, entity_id, entity_version, operation, payload)
      VALUES (v_user_id, 'wishlist', v_entity_id, v_new_version, 'upsert', v_payload || jsonb_build_object('id', v_entity_id, 'version', v_new_version));

    ELSE
      -- Generic sync change log for debt, debt_payment, installment_plan, installment_payment, category
      INSERT INTO public.sync_changes (user_id, entity_type, entity_id, entity_version, operation, payload)
      VALUES (
        v_user_id,
        v_entity_type,
        v_entity_id,
        v_new_version,
        CASE WHEN v_action = 'archive' THEN 'tombstone' ELSE 'upsert' END,
        v_payload || jsonb_build_object('id', v_entity_id, 'version', v_new_version)
      );
    END IF;

    v_result_entry := jsonb_build_object(
      'operation_id', v_op_id,
      'entity_type', v_entity_type,
      'entity_id', v_entity_id,
      'status', 'applied',
      'entity_version', v_new_version
    );

    INSERT INTO public.sync_operations (operation_id, user_id, device_id, entity_type, entity_id, action, response_snapshot)
    VALUES (v_op_id, v_user_id, p_device_id, v_entity_type, v_entity_id, v_action, v_result_entry);

    v_results := v_results || jsonb_build_array(v_result_entry);
  END LOOP;

  SELECT coalesce(max(id), 0) INTO v_cursor FROM public.sync_changes WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'results', v_results,
      'server_cursor', v_cursor::text
    )
  );
END;
$$;

-- 10. RPC: Cursor-Paginated Sync Pull
CREATE OR REPLACE FUNCTION public.sync_pull(
  p_token text,
  p_cursor text DEFAULT NULL,
  p_limit integer DEFAULT 200
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_after_id bigint := 0;
  v_limit integer := greatest(1, least(coalesce(p_limit, 200), 500));
  v_changes jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor text;
  v_count integer := 0;
  v_row record;
BEGIN
  v_user_id := public.verify_app_token(p_token);

  IF p_cursor IS NOT NULL AND trim(p_cursor) ~ '^[0-9]+$' THEN
    v_after_id := trim(p_cursor)::bigint;
  END IF;

  v_next_cursor := v_after_id::text;

  FOR v_row IN
    SELECT id, entity_type, entity_id, entity_version, operation, payload, created_at
    FROM public.sync_changes
    WHERE user_id = v_user_id AND id > v_after_id
    ORDER BY id ASC
    LIMIT (v_limit + 1)
  LOOP
    v_count := v_count + 1;
    IF v_count <= v_limit THEN
      v_changes := v_changes || jsonb_build_array(jsonb_build_object(
        'change_id', v_row.id,
        'entity_type', v_row.entity_type,
        'entity_id', v_row.entity_id,
        'entity_version', v_row.entity_version,
        'operation', v_row.operation,
        'changed_at', to_char(v_row.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'payload', v_row.payload
      ));
      v_next_cursor := v_row.id::text;
    ELSE
      v_has_more := true;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'data', jsonb_build_object(
      'changes', v_changes,
      'next_cursor', v_next_cursor,
      'has_more', v_has_more
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.app_register(text, text, text, uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_login(text, text, uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.app_logout(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_push(text, uuid, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sync_pull(text, text, integer) TO anon, authenticated;
