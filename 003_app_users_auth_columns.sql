-- ══════════════════════════════════════════════════════════════════════════════
--  003_app_users_auth_columns.sql
--  Idempotent app_users auth/client-scope migration for older databases.
--
--  Adds the first-class columns that `_worker.js` already reads/writes:
--    * password_changed_at  -> token/session invalidation after password changes
--    * client_id            -> tenant scoping and client-aware user lookup
--
--  Also ensures the admin/auth profile fields used by the worker exist when
--  bootstrapping older databases that predate the current app_users contract.
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE app_users
  ADD COLUMN IF NOT EXISTS password text,
  ADD COLUMN IF NOT EXISTS active boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS dept text,
  ADD COLUMN IF NOT EXISTS color text,
  ADD COLUMN IF NOT EXISTS initials text,
  ADD COLUMN IF NOT EXISTS client_id text,
  ADD COLUMN IF NOT EXISTS password_changed_at timestamptz,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

UPDATE app_users
SET active = COALESCE(active, true)
WHERE active IS NULL;

UPDATE app_users
SET client_id = NULLIF(trim(client_id), '')
WHERE client_id IS NOT NULL;

UPDATE app_users
SET password_changed_at = COALESCE(password_changed_at, updated_at, created_at)
WHERE password IS NOT NULL
  AND btrim(password) <> ''
  AND password_changed_at IS NULL;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'clients'
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'app_users_client_id_fkey'
  ) THEN
    ALTER TABLE app_users
      ADD CONSTRAINT app_users_client_id_fkey
      FOREIGN KEY (client_id)
      REFERENCES clients(id)
      ON UPDATE CASCADE
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_app_users_email ON app_users (email);
CREATE INDEX IF NOT EXISTS idx_app_users_client_id ON app_users (client_id);
CREATE INDEX IF NOT EXISTS idx_app_users_password_changed_at ON app_users (password_changed_at);
