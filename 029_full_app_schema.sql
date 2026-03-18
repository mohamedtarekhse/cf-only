-- 029_full_app_schema.sql
-- Consolidated bootstrap schema aligned with the current frontend + _worker.js API.
-- Idempotent: safe to run multiple times.

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION set_row_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Core tenant table
CREATE TABLE IF NOT EXISTS clients (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  active      BOOLEAN NOT NULL DEFAULT TRUE,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT clients_name_key UNIQUE (name)
);

-- Core master tables
CREATE TABLE IF NOT EXISTS assets (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id         TEXT UNIQUE NOT NULL,
  client_id        TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id  TEXT REFERENCES clients(id) ON DELETE SET NULL,
  name       TEXT NOT NULL,
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
  client_id  TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id   TEXT REFERENCES clients(id) ON DELETE SET NULL,
  contract_id TEXT NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
  asset_id    TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (contract_id, asset_id)
);

CREATE TABLE IF NOT EXISTS bom_items (
  id           TEXT PRIMARY KEY,
  bom_id       TEXT UNIQUE,
  client_id    TEXT REFERENCES clients(id) ON DELETE SET NULL,
  asset_id     TEXT REFERENCES assets(asset_id) ON DELETE CASCADE,
  parent_id    TEXT,
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
  cert_id         TEXT UNIQUE NOT NULL,
  client_id       TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id  TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id       TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id          TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id           TEXT REFERENCES clients(id) ON DELETE SET NULL,
  name                TEXT NOT NULL,
  role                TEXT NOT NULL DEFAULT 'Viewer',
  dept                TEXT,
  email               TEXT UNIQUE NOT NULL,
  color               TEXT,
  initials            TEXT,
  password            TEXT,
  active              BOOLEAN NOT NULL DEFAULT TRUE,
  password_changed_at TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inspections (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id        TEXT REFERENCES clients(id) ON DELETE SET NULL,
  reg_id           TEXT,
  inspection_type  TEXT,
  rig_name         TEXT,
  asset_id         TEXT,
  inspected_by     TEXT,
  start_date       DATE,
  due_date         DATE,
  status           TEXT,
  findings         TEXT,
  recommendation   TEXT,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id     TEXT UNIQUE NOT NULL,
  client_id      TEXT REFERENCES clients(id) ON DELETE SET NULL,
  name           TEXT,
  rig_name       TEXT,
  status         TEXT,
  priority       TEXT,
  start_date     DATE,
  end_date       DATE,
  budget         NUMERIC(14,2),
  spent          NUMERIC(14,2),
  manager        TEXT,
  description    TEXT,
  notes          TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workshops (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workshop_id   TEXT UNIQUE NOT NULL,
  client_id     TEXT REFERENCES clients(id) ON DELETE SET NULL,
  workshop_name TEXT NOT NULL,
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
  client_id   TEXT REFERENCES clients(id) ON DELETE SET NULL,
  user_id     UUID REFERENCES app_users(id) ON DELETE CASCADE,
  icon        TEXT,
  type        TEXT,
  kind        TEXT,
  event_type  TEXT,
  title       TEXT,
  description TEXT,
  link        TEXT,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id       UUID REFERENCES app_users(id) ON DELETE CASCADE,
  client_id     TEXT REFERENCES clients(id) ON DELETE SET NULL,
  endpoint      TEXT NOT NULL,
  p256dh        TEXT NOT NULL,
  auth          TEXT NOT NULL,
  platform      TEXT,
  user_agent    TEXT,
  is_standalone BOOLEAN NOT NULL DEFAULT FALSE,
  active        BOOLEAN NOT NULL DEFAULT TRUE,
  last_used_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint)
);

CREATE TABLE IF NOT EXISTS delete_requests (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id            TEXT REFERENCES clients(id) ON DELETE SET NULL,
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

-- Register tables used by generic /api/reg-* helper
CREATE TABLE IF NOT EXISTS reg_bop (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
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
  client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Backfill missing columns when run against an existing database.
ALTER TABLE assets                 ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE rigs                   ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE contracts              ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE contract_assets        ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE bom_items              ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE certificates           ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE maintenance_schedules  ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE maintenance_logs       ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE transfers              ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE app_users              ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE app_users              ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
ALTER TABLE inspections            ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE projects               ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE workshops              ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE notifications          ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE notifications          ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE notifications          ADD COLUMN IF NOT EXISTS kind TEXT;
ALTER TABLE notifications          ADD COLUMN IF NOT EXISTS event_type TEXT;
ALTER TABLE notifications          ADD COLUMN IF NOT EXISTS link TEXT;
ALTER TABLE notifications          ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS endpoint TEXT;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS p256dh TEXT;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS auth TEXT;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS platform TEXT;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS is_standalone BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ;
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE push_subscriptions     ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS resource TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS record_id TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS record_label TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS requested_by_user_id UUID;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS requested_by_name TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS requested_by_role TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'Pending';
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS reviewed_by_user_id UUID;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS reviewed_by_name TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS review_comment TEXT;
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE delete_requests        ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE reg_bop                ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE reg_well_head          ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE reg_well_control       ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE reg_fire_extinguishers ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE reg_scba               ADD COLUMN IF NOT EXISTS client_id TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contract_assets_client_id_fkey') THEN
    ALTER TABLE contract_assets
      ADD CONSTRAINT contract_assets_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bom_items_parent_id_fkey') THEN
    ALTER TABLE bom_items
      ADD CONSTRAINT bom_items_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES bom_items(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'maintenance_logs_client_id_fkey') THEN
    ALTER TABLE maintenance_logs
      ADD CONSTRAINT maintenance_logs_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'notifications_user_id_fkey') THEN
    ALTER TABLE notifications
      ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'push_subscriptions_user_id_fkey') THEN
    ALTER TABLE push_subscriptions
      ADD CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'push_subscriptions_client_id_fkey') THEN
    ALTER TABLE push_subscriptions
      ADD CONSTRAINT push_subscriptions_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_requested_by_user_id_fkey') THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_requested_by_user_id_fkey FOREIGN KEY (requested_by_user_id) REFERENCES app_users(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_reviewed_by_user_id_fkey') THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_reviewed_by_user_id_fkey FOREIGN KEY (reviewed_by_user_id) REFERENCES app_users(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'delete_requests_client_id_fkey') THEN
    ALTER TABLE delete_requests
      ADD CONSTRAINT delete_requests_client_id_fkey FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Helpful indexes for current query patterns.
CREATE INDEX IF NOT EXISTS idx_assets_asset_id                  ON assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_assets_client_id                 ON assets(client_id);
CREATE INDEX IF NOT EXISTS idx_assets_client_id_updated_at      ON assets(client_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_assets_rig_name                  ON assets(rig_name);
CREATE INDEX IF NOT EXISTS idx_assets_status                    ON assets(status);

CREATE INDEX IF NOT EXISTS idx_rigs_client_id                   ON rigs(client_id);
CREATE INDEX IF NOT EXISTS idx_rigs_client_id_updated_at        ON rigs(client_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_rigs_name                        ON rigs(name);

CREATE INDEX IF NOT EXISTS idx_contracts_client_id              ON contracts(client_id);
CREATE INDEX IF NOT EXISTS idx_contracts_updated_at             ON contracts(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_contract_assets_contract_id      ON contract_assets(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_assets_asset_id         ON contract_assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_contract_assets_client_id        ON contract_assets(client_id);

CREATE INDEX IF NOT EXISTS idx_bom_items_asset_id               ON bom_items(asset_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_parent_id              ON bom_items(parent_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_client_id              ON bom_items(client_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_updated_at             ON bom_items(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_certificates_asset_id            ON certificates(asset_id);
CREATE INDEX IF NOT EXISTS idx_certificates_client_id           ON certificates(client_id);
CREATE INDEX IF NOT EXISTS idx_certificates_client_cert_id      ON certificates(client_id, cert_id);
CREATE INDEX IF NOT EXISTS idx_certificates_updated_at          ON certificates(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_maint_sched_asset_id             ON maintenance_schedules(asset_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_client_id            ON maintenance_schedules(client_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_next_due             ON maintenance_schedules(next_due);
CREATE INDEX IF NOT EXISTS idx_maint_sched_updated_at           ON maintenance_schedules(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_maint_logs_schedule_id           ON maintenance_logs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_maint_logs_client_id             ON maintenance_logs(client_id);

CREATE INDEX IF NOT EXISTS idx_transfers_asset_id               ON transfers(asset_id);
CREATE INDEX IF NOT EXISTS idx_transfers_client_id              ON transfers(client_id);
CREATE INDEX IF NOT EXISTS idx_transfers_status                 ON transfers(status);
CREATE INDEX IF NOT EXISTS idx_transfers_updated_at             ON transfers(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_transfers_created_at             ON transfers(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_users_client_id              ON app_users(client_id);
CREATE INDEX IF NOT EXISTS idx_app_users_client_active          ON app_users(client_id, active);
CREATE INDEX IF NOT EXISTS idx_app_users_client_name            ON app_users(client_id, name);
CREATE INDEX IF NOT EXISTS idx_app_users_updated_at             ON app_users(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_users_password_changed_at    ON app_users(password_changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_inspections_client_id            ON inspections(client_id);
CREATE INDEX IF NOT EXISTS idx_inspections_rig_name             ON inspections(rig_name);
CREATE INDEX IF NOT EXISTS idx_inspections_updated_at           ON inspections(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_projects_project_id              ON projects(project_id);
CREATE INDEX IF NOT EXISTS idx_projects_client_id               ON projects(client_id);
CREATE INDEX IF NOT EXISTS idx_projects_updated_at              ON projects(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_projects_created_at              ON projects(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_workshops_workshop_id            ON workshops(workshop_id);
CREATE INDEX IF NOT EXISTS idx_workshops_client_id              ON workshops(client_id);
CREATE INDEX IF NOT EXISTS idx_workshops_updated_at             ON workshops(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_workshops_created_at             ON workshops(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_is_read            ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id            ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_client_id          ON notifications(client_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created_at    ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_client_created_at  ON notifications(client_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id       ON push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_client_id     ON push_subscriptions(client_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint      ON push_subscriptions(endpoint);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active        ON push_subscriptions(active);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_active   ON push_subscriptions(user_id, active);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_updated_at    ON push_subscriptions(updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_delete_requests_status           ON delete_requests(status);
CREATE INDEX IF NOT EXISTS idx_delete_requests_client_id        ON delete_requests(client_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_requested_by     ON delete_requests(requested_by_user_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_reviewed_by      ON delete_requests(reviewed_by_user_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_resource_record  ON delete_requests(resource, record_id);
CREATE INDEX IF NOT EXISTS idx_delete_requests_created_at       ON delete_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_delete_requests_updated_at       ON delete_requests(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_delete_requests_pending_lookup   ON delete_requests(resource, record_id, status);

CREATE INDEX IF NOT EXISTS idx_clients_updated_at               ON clients(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_reg_bop_client_id                ON reg_bop(client_id);
CREATE INDEX IF NOT EXISTS idx_reg_well_head_client_id          ON reg_well_head(client_id);
CREATE INDEX IF NOT EXISTS idx_reg_well_control_client_id       ON reg_well_control(client_id);
CREATE INDEX IF NOT EXISTS idx_reg_fire_extinguishers_client_id ON reg_fire_extinguishers(client_id);
CREATE INDEX IF NOT EXISTS idx_reg_scba_client_id               ON reg_scba(client_id);

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'clients',
    'assets',
    'rigs',
    'contracts',
    'bom_items',
    'certificates',
    'maintenance_schedules',
    'transfers',
    'app_users',
    'inspections',
    'projects',
    'workshops',
    'notifications',
    'push_subscriptions',
    'delete_requests',
    'reg_bop',
    'reg_well_head',
    'reg_well_control',
    'reg_fire_extinguishers',
    'reg_scba'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_trigger
      WHERE tgname = 'trg_' || tbl || '_set_updated_at'
    ) THEN
      EXECUTE format(
        'CREATE TRIGGER %I BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_row_updated_at()',
        'trg_' || tbl || '_set_updated_at',
        tbl
      );
    END IF;
  END LOOP;
END $$;

COMMIT;
