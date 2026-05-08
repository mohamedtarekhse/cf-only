-- 030_safe_non_breaking_migration-base.sql
-- Production-safe additive migration to align existing databases with the current Worker contract.

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.app_hash_password(plain_password TEXT, cost INTEGER DEFAULT 10)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT crypt(
    COALESCE(plain_password, ''),
    gen_salt('bf', GREATEST(4, LEAST(COALESCE(cost, 10), 31)))
  );
$$;

CREATE OR REPLACE FUNCTION public.app_verify_password(plain_password TEXT, stored_hash TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT stored_hash IS NOT NULL
     AND stored_hash <> ''
     AND crypt(COALESCE(plain_password, ''), stored_hash) = stored_hash;
$$;

CREATE TABLE IF NOT EXISTS clients (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  code       TEXT UNIQUE,
  active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID,
  client_id     UUID,
  endpoint      TEXT UNIQUE NOT NULL,
  p256dh        TEXT NOT NULL,
  auth          TEXT NOT NULL,
  platform      TEXT,
  user_agent    TEXT,
  is_standalone BOOLEAN NOT NULL DEFAULT FALSE,
  active        BOOLEAN NOT NULL DEFAULT TRUE,
  last_used_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS delete_requests (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id            UUID,
  resource             TEXT NOT NULL,
  record_id            TEXT NOT NULL,
  record_label         TEXT,
  requested_by_user_id UUID,
  requested_by_name    TEXT,
  requested_by_role    TEXT,
  reason               TEXT,
  status               TEXT NOT NULL DEFAULT 'Pending',
  reviewed_by_user_id  UUID,
  reviewed_by_name     TEXT,
  reviewed_at          TIMESTAMPTZ,
  review_comment       TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS code TEXT;
ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS clients ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS rig_name TEXT;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS app_users ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS app_users ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS kind TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS link TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS event_type TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS time_label TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS endpoint TEXT;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS p256dh TEXT;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS auth TEXT;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS platform TEXT;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS is_standalone BOOLEAN DEFAULT FALSE;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS push_subscriptions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS client_id UUID;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS resource TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS record_id TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS record_label TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS requested_by_user_id UUID;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS requested_by_name TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS requested_by_role TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Pending';
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS reviewed_by_user_id UUID;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS review_comment TEXT;
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE IF EXISTS delete_requests ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

DO $$
BEGIN
  IF to_regclass('public.workshops') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE workshops ADD COLUMN IF NOT EXISTS name TEXT';
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.assets') IS NOT NULL AND to_regclass('public.rigs') IS NOT NULL THEN
    UPDATE assets a
    SET client_id = r.client_id
    FROM rigs r
    WHERE a.client_id IS NULL
      AND a.rig_name IS NOT NULL
      AND (r.name = a.rig_name OR r.rig_name = a.rig_name)
      AND r.client_id IS NOT NULL;
  END IF;

  IF to_regclass('public.assets') IS NOT NULL AND to_regclass('public.certificates') IS NOT NULL THEN
    UPDATE certificates c
    SET client_id = a.client_id
    FROM assets a
    WHERE c.client_id IS NULL
      AND c.asset_id = a.asset_id
      AND a.client_id IS NOT NULL;
  END IF;

  IF to_regclass('public.assets') IS NOT NULL AND to_regclass('public.transfers') IS NOT NULL THEN
    UPDATE transfers t
    SET client_id = a.client_id
    FROM assets a
    WHERE t.client_id IS NULL
      AND t.asset_id = a.asset_id
      AND a.client_id IS NOT NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.assets') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'assets_client_id_fkey'
  ) THEN
    ALTER TABLE assets
      ADD CONSTRAINT assets_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.rigs') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'rigs_client_id_fkey'
  ) THEN
    ALTER TABLE rigs
      ADD CONSTRAINT rigs_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.certificates') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'certificates_client_id_fkey'
  ) THEN
    ALTER TABLE certificates
      ADD CONSTRAINT certificates_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.transfers') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'transfers_client_id_fkey'
  ) THEN
    ALTER TABLE transfers
      ADD CONSTRAINT transfers_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.app_users') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'app_users_client_id_fkey'
  ) THEN
    ALTER TABLE app_users
      ADD CONSTRAINT app_users_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.notifications') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'notifications_client_id_fkey'
  ) THEN
    ALTER TABLE notifications
      ADD CONSTRAINT notifications_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.notifications') IS NOT NULL AND to_regclass('public.app_users') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'notifications_user_id_fkey'
  ) THEN
    ALTER TABLE notifications
      ADD CONSTRAINT notifications_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE;
  END IF;
  IF to_regclass('public.push_subscriptions') IS NOT NULL AND to_regclass('public.app_users') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'push_subscriptions_user_id_fkey'
  ) THEN
    ALTER TABLE push_subscriptions
      ADD CONSTRAINT push_subscriptions_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE;
  END IF;
  IF to_regclass('public.push_subscriptions') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'push_subscriptions_client_id_fkey'
  ) THEN
    ALTER TABLE push_subscriptions
      ADD CONSTRAINT push_subscriptions_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.delete_requests') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_client_id_fkey'
  ) THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.delete_requests') IS NOT NULL AND to_regclass('public.app_users') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_requested_by_user_id_fkey'
  ) THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_requested_by_user_id_fkey
      FOREIGN KEY (requested_by_user_id) REFERENCES app_users(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.delete_requests') IS NOT NULL AND to_regclass('public.app_users') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_reviewed_by_user_id_fkey'
  ) THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_reviewed_by_user_id_fkey
      FOREIGN KEY (reviewed_by_user_id) REFERENCES app_users(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.maintenance_schedules') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'maintenance_schedules_status_chk'
  ) THEN
    ALTER TABLE maintenance_schedules
      ADD CONSTRAINT maintenance_schedules_status_chk
      CHECK (status IN ('Scheduled','In Progress','Completed','Cancelled','Overdue','Due Soon')) NOT VALID;
  END IF;
  IF to_regclass('public.delete_requests') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_status_chk'
  ) THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_status_chk
      CHECK (status IN ('Pending','Approved','Rejected')) NOT VALID;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_clients_name ON clients(name);
CREATE INDEX IF NOT EXISTS idx_assets_client_id ON assets(client_id);
CREATE INDEX IF NOT EXISTS idx_rigs_client_id ON rigs(client_id);
CREATE INDEX IF NOT EXISTS idx_rigs_rig_name ON rigs(rig_name);
CREATE INDEX IF NOT EXISTS idx_certificates_client_id ON certificates(client_id);
CREATE INDEX IF NOT EXISTS idx_transfers_client_id ON transfers(client_id);
CREATE INDEX IF NOT EXISTS idx_app_users_client_id ON app_users(client_id);
CREATE INDEX IF NOT EXISTS idx_notifications_client_id ON notifications(client_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_client_id ON push_subscriptions(client_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint ON push_subscriptions(endpoint);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active ON push_subscriptions(active);
CREATE INDEX IF NOT EXISTS idx_delete_requests_client_id ON delete_requests(client_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_status ON delete_requests(status);
CREATE INDEX IF NOT EXISTS idx_delete_requests_resource_record ON delete_requests(resource, record_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_requested_by ON delete_requests(requested_by_user_id);

COMMIT;
