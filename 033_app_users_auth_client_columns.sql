-- 033_app_users_auth_client_columns.sql
-- Adds auth/session invalidation support plus user-to-client scoping.
-- Safe to run on existing environments before deploying _worker.js auth flows.

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS clients (
  id         TEXT PRIMARY KEY DEFAULT ('client-' || substr(replace(uuid_generate_v4()::text, '-', ''), 1, 12)),
  name       TEXT NOT NULL UNIQUE,
  code       TEXT UNIQUE,
  active     BOOLEAN DEFAULT TRUE,
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS app_users
  ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS client_id TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'app_users_client_id_fkey'
      AND conrelid = 'app_users'::regclass
  ) THEN
    ALTER TABLE app_users
      ADD CONSTRAINT app_users_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_app_users_client_id ON app_users(client_id);
CREATE INDEX IF NOT EXISTS idx_app_users_password_changed_at ON app_users(password_changed_at);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_clients_set_updated_at ON clients;
CREATE TRIGGER trg_clients_set_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION app_users_sync_auth_columns()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();

  IF TG_OP = 'INSERT' THEN
    IF NEW.password_changed_at IS NULL AND NULLIF(BTRIM(COALESCE(NEW.password, '')), '') IS NOT NULL THEN
      NEW.password_changed_at = NOW();
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.password IS DISTINCT FROM OLD.password
     AND NULLIF(BTRIM(COALESCE(NEW.password, '')), '') IS NOT NULL THEN
    NEW.password_changed_at = NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_app_users_sync_auth_columns ON app_users;
CREATE TRIGGER trg_app_users_sync_auth_columns
BEFORE INSERT OR UPDATE ON app_users
FOR EACH ROW
EXECUTE FUNCTION app_users_sync_auth_columns();

-- Backfill only rows that already have a password so existing tokens can be
-- compared against a stable schema column immediately after deployment.
UPDATE app_users
SET password_changed_at = COALESCE(password_changed_at, updated_at, created_at, NOW())
WHERE password_changed_at IS NULL
  AND NULLIF(BTRIM(COALESCE(password, '')), '') IS NOT NULL;

COMMIT;
