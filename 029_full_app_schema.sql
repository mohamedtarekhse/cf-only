-- 029_full_app_schema.sql
-- Canonical schema snapshot aligned with the current Cloudflare Worker contract.
-- Idempotent: safe to run on a fresh database.

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

CREATE TABLE IF NOT EXISTS assets (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id        UUID REFERENCES clients(id) ON DELETE SET NULL,
  asset_id         TEXT UNIQUE NOT NULL,
  name             TEXT NOT NULL,
  category         TEXT,
  status           TEXT DEFAULT 'Active',
  rig_name         TEXT,
  location         TEXT,
  serial           TEXT,
  notes            TEXT,
  last_inspection  DATE,
  inspection_type  TEXT,
  cert_link        TEXT,
  acquisition_date DATE,
  value            NUMERIC(14,2) DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rigs (
  id         TEXT PRIMARY KEY,
  client_id  UUID REFERENCES clients(id) ON DELETE SET NULL,
  name       TEXT NOT NULL,
  rig_name   TEXT,
  type       TEXT,
  location   TEXT,
  depth      TEXT,
  hp         INTEGER,
  status     TEXT DEFAULT 'Active',
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contracts (
  id         TEXT PRIMARY KEY,
  rig        TEXT,
  value      NUMERIC(14,2) DEFAULT 0,
  start_date DATE,
  end_date   DATE,
  status     TEXT DEFAULT 'Pending',
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contract_assets (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contract_id TEXT NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
  asset_id    TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (contract_id, asset_id)
);

CREATE TABLE IF NOT EXISTS bom_items (
  id           TEXT PRIMARY KEY,
  bom_id       TEXT UNIQUE,
  asset_id     TEXT REFERENCES assets(asset_id) ON DELETE CASCADE,
  parent_id    TEXT REFERENCES bom_items(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  part_no      TEXT,
  type         TEXT DEFAULT 'Serialized',
  serial       TEXT,
  manufacturer TEXT,
  qty          INTEGER DEFAULT 1,
  uom          TEXT DEFAULT 'EA',
  unit_cost    NUMERIC(12,2) DEFAULT 0,
  lead_time    INTEGER DEFAULT 0,
  status       TEXT DEFAULT 'Active',
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS certificates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id       UUID REFERENCES clients(id) ON DELETE SET NULL,
  cert_id         TEXT UNIQUE NOT NULL,
  asset_id        TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  inspection_type TEXT NOT NULL,
  last_inspection DATE,
  next_inspection DATE,
  validity_days   INTEGER DEFAULT 365,
  alert_days      INTEGER DEFAULT 30,
  cert_link       TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id         TEXT PRIMARY KEY,
  asset_id   TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  task       TEXT NOT NULL,
  type       TEXT DEFAULT 'Inspection',
  priority   TEXT DEFAULT 'Normal',
  freq       INTEGER DEFAULT 90,
  last_done  DATE,
  next_due   DATE,
  tech       TEXT,
  hours      NUMERIC(8,2),
  cost       NUMERIC(12,2),
  status     TEXT DEFAULT 'Scheduled',
  alert_days INTEGER DEFAULT 14,
  notes      TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  schedule_id     TEXT NOT NULL REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
  completion_date DATE NOT NULL,
  performed_by    TEXT NOT NULL,
  hours           NUMERIC(8,2),
  cost            NUMERIC(12,2),
  parts_used      TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transfers (
  id                 TEXT PRIMARY KEY,
  client_id          UUID REFERENCES clients(id) ON DELETE SET NULL,
  asset_id           TEXT REFERENCES assets(asset_id) ON DELETE SET NULL,
  asset_name         TEXT,
  current_loc        TEXT,
  destination        TEXT,
  dest_rig           TEXT,
  priority           TEXT DEFAULT 'Normal',
  type               TEXT DEFAULT 'Field to Field',
  requested_by       TEXT,
  request_date       DATE,
  required_date      DATE,
  reason             TEXT,
  instructions       TEXT,
  status             TEXT DEFAULT 'Pending',
  vendor_name        TEXT,
  vendor_type        TEXT,
  po_number          TEXT,
  vendor_contact     TEXT,
  return_date        DATE,
  bom_item_id        TEXT,
  bom_item_name      TEXT,
  bom_part_no        TEXT,
  supt_approved_by   TEXT,
  supt_approved_date DATE,
  supt_action        TEXT,
  supt_comment       TEXT,
  ops_approved_by    TEXT,
  ops_approved_date  DATE,
  ops_action         TEXT,
  ops_comment        TEXT,
  mgr_approved_by    TEXT,
  mgr_approved_date  DATE,
  mgr_action         TEXT,
  mgr_comment        TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_users (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id           UUID REFERENCES clients(id) ON DELETE SET NULL,
  name                TEXT NOT NULL,
  role                TEXT NOT NULL DEFAULT 'Viewer',
  dept                TEXT,
  email               TEXT UNIQUE NOT NULL,
  color               TEXT,
  initials            TEXT,
  password            TEXT,
  password_changed_at TIMESTAMPTZ,
  active              BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inspections (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id          TEXT,
  inspection_type TEXT,
  rig_name        TEXT,
  asset_id        TEXT,
  inspected_by    TEXT,
  start_date      DATE,
  due_date        DATE,
  status          TEXT,
  findings        TEXT,
  recommendation  TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id  TEXT UNIQUE NOT NULL,
  name        TEXT,
  rig_name    TEXT,
  status      TEXT,
  priority    TEXT,
  start_date  DATE,
  end_date    DATE,
  budget      NUMERIC(14,2),
  spent       NUMERIC(14,2),
  manager     TEXT,
  description TEXT,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workshops (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workshop_id   TEXT UNIQUE NOT NULL,
  workshop_name TEXT NOT NULL,
  name          TEXT,
  location      TEXT,
  assigned_rig  TEXT,
  asset_id      TEXT,
  asset_name    TEXT,
  asset_serial  TEXT,
  scope_of_work TEXT,
  start_date    DATE,
  end_date      DATE,
  status        TEXT DEFAULT 'Active',
  technician    TEXT,
  contact       TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id   UUID REFERENCES clients(id) ON DELETE SET NULL,
  user_id     UUID REFERENCES app_users(id) ON DELETE CASCADE,
  icon        TEXT,
  type        TEXT,
  kind        TEXT,
  title       TEXT,
  description TEXT,
  link        TEXT,
  event_type  TEXT,
  time_label  TEXT,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  client_id     UUID REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id            UUID REFERENCES clients(id) ON DELETE SET NULL,
  resource             TEXT NOT NULL,
  record_id            TEXT NOT NULL,
  record_label         TEXT,
  requested_by_user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  requested_by_name    TEXT,
  requested_by_role    TEXT,
  reason               TEXT,
  status               TEXT NOT NULL DEFAULT 'Pending',
  reviewed_by_user_id  UUID REFERENCES app_users(id) ON DELETE SET NULL,
  reviewed_by_name     TEXT,
  reviewed_at          TIMESTAMPTZ,
  review_comment       TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_bop (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_well_head (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_well_control (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_fire_extinguishers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_scba (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'maintenance_schedules_status_chk'
  ) THEN
    ALTER TABLE maintenance_schedules
      ADD CONSTRAINT maintenance_schedules_status_chk
      CHECK (status IN ('Scheduled','In Progress','Completed','Cancelled','Overdue','Due Soon'));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_status_chk'
  ) THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_status_chk
      CHECK (status IN ('Pending','Approved','Rejected'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_clients_name ON clients(name);
CREATE INDEX IF NOT EXISTS idx_assets_asset_id ON assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_assets_client_id ON assets(client_id);
CREATE INDEX IF NOT EXISTS idx_assets_rig_name ON assets(rig_name);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_rigs_client_id ON rigs(client_id);
CREATE INDEX IF NOT EXISTS idx_rigs_name ON rigs(name);
CREATE INDEX IF NOT EXISTS idx_rigs_rig_name ON rigs(rig_name);
CREATE INDEX IF NOT EXISTS idx_contract_assets_contract_id ON contract_assets(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_assets_asset_id ON contract_assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_asset_id ON bom_items(asset_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_parent_id ON bom_items(parent_id);
CREATE INDEX IF NOT EXISTS idx_certificates_asset_id ON certificates(asset_id);
CREATE INDEX IF NOT EXISTS idx_certificates_client_id ON certificates(client_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_asset_id ON maintenance_schedules(asset_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_next_due ON maintenance_schedules(next_due);
CREATE INDEX IF NOT EXISTS idx_maint_logs_schedule_id ON maintenance_logs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_transfers_asset_id ON transfers(asset_id);
CREATE INDEX IF NOT EXISTS idx_transfers_client_id ON transfers(client_id);
CREATE INDEX IF NOT EXISTS idx_transfers_status ON transfers(status);
CREATE INDEX IF NOT EXISTS idx_app_users_client_id ON app_users(client_id);
CREATE INDEX IF NOT EXISTS idx_app_users_email ON app_users(email);
CREATE INDEX IF NOT EXISTS idx_projects_project_id ON projects(project_id);
CREATE INDEX IF NOT EXISTS idx_workshops_workshop_id ON workshops(workshop_id);
CREATE INDEX IF NOT EXISTS idx_notifications_client_id ON notifications(client_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_client_id ON push_subscriptions(client_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint ON push_subscriptions(endpoint);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active ON push_subscriptions(active);
CREATE INDEX IF NOT EXISTS idx_delete_requests_client_id ON delete_requests(client_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_status ON delete_requests(status);
CREATE INDEX IF NOT EXISTS idx_delete_requests_resource_record ON delete_requests(resource, record_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_requested_by ON delete_requests(requested_by_user_id);

COMMIT;
