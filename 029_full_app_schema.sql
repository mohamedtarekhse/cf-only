-- 029_full_app_schema.sql
-- Consolidated schema aligned with current frontend + _worker.js API.
-- Idempotent: safe to run multiple times.

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Core master tables
CREATE TABLE IF NOT EXISTS assets (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rigs (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  type       TEXT,
  location   TEXT,
  depth      TEXT,
  hp         INTEGER,
  status     TEXT DEFAULT 'Active',
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contracts (
  id         TEXT PRIMARY KEY,
  rig        TEXT,
  value      NUMERIC(14,2) DEFAULT 0,
  start_date DATE,
  end_date   DATE,
  status     TEXT DEFAULT 'Pending',
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contract_assets (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contract_id TEXT NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
  asset_id    TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (contract_id, asset_id)
);

CREATE TABLE IF NOT EXISTS bom_items (
  id           TEXT PRIMARY KEY,
  bom_id       TEXT UNIQUE,
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
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS certificates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cert_id         TEXT UNIQUE NOT NULL,
  asset_id        TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  inspection_type TEXT NOT NULL,
  last_inspection DATE,
  next_inspection DATE,
  validity_days   INTEGER DEFAULT 365,
  alert_days      INTEGER DEFAULT 30,
  cert_link       TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
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
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
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
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transfers (
  id                 TEXT PRIMARY KEY,
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
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_users (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'Viewer',
  dept       TEXT,
  email      TEXT UNIQUE NOT NULL,
  color      TEXT,
  initials   TEXT,
  password   TEXT,
  active     BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS login_history (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL,
  logged_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address   TEXT,
  user_agent   TEXT,
  CONSTRAINT login_history_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS inspections (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id     TEXT UNIQUE NOT NULL,
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
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workshops (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workshop_id   TEXT UNIQUE NOT NULL,
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
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  icon        TEXT,
  type        TEXT,
  title       TEXT,
  description TEXT,
  is_read     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Register tables used by generic /api/reg-* helper
CREATE TABLE IF NOT EXISTS reg_bop (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_well_head (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_well_control (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_fire_extinguishers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS reg_scba (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id TEXT,
  rig TEXT,
  inspection_date DATE,
  due_date DATE,
  inspection_status TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_assets_asset_id ON assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_assets_rig_name ON assets(rig_name);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_contract_assets_contract_id ON contract_assets(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_assets_asset_id ON contract_assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_asset_id ON bom_items(asset_id);
CREATE INDEX IF NOT EXISTS idx_certificates_asset_id ON certificates(asset_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_asset_id ON maintenance_schedules(asset_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_next_due ON maintenance_schedules(next_due);
CREATE INDEX IF NOT EXISTS idx_maint_logs_schedule_id ON maintenance_logs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_transfers_asset_id ON transfers(asset_id);
CREATE INDEX IF NOT EXISTS idx_transfers_status ON transfers(status);
CREATE INDEX IF NOT EXISTS idx_login_history_user_id ON login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_logged_in_at ON login_history(logged_in_at DESC);
CREATE INDEX IF NOT EXISTS idx_projects_project_id ON projects(project_id);
CREATE INDEX IF NOT EXISTS idx_workshops_workshop_id ON workshops(workshop_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

COMMIT;
