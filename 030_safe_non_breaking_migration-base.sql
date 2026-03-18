-- 030_safe_non_breaking_migration-base.sql
-- Additive app_users password change tracking hardening.

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS public.app_users (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name                TEXT,
  role                TEXT DEFAULT 'Viewer',
  dept                TEXT,
  email               TEXT UNIQUE,
  color               TEXT,
  initials            TEXT,
  password            TEXT,
  active              BOOLEAN DEFAULT TRUE,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW(),
  password_changed_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE IF EXISTS public.app_users
  ADD COLUMN IF NOT EXISTS password TEXT;

ALTER TABLE IF EXISTS public.app_users
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.app_users
  ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ DEFAULT NOW();

CREATE OR REPLACE FUNCTION public.set_password_changed_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.password IS DISTINCT FROM OLD.password THEN
    NEW.password_changed_at = NOW();
  END IF;

  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_password_changed_at ON public.app_users;

CREATE TRIGGER set_password_changed_at
BEFORE UPDATE OF password ON public.app_users
FOR EACH ROW
EXECUTE FUNCTION public.set_password_changed_at();

COMMIT;
