-- 030_safe_non_breaking_migration.sql
-- Production-safe additive migration.
-- No DROP/RENAME operations. Designed for mixed legacy schemas.

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1) Ensure required tables exist (minimal compatible shape)
-- ============================================================

CREATE TABLE IF NOT EXISTS assets (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id         TEXT UNIQUE NOT NULL,
  name             TEXT NOT NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rigs (
  id         TEXT PRIMARY KEY,
  name       TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contracts (
  id         TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS contract_assets (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contract_id TEXT,
  asset_id    TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bom_items (
  id         TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS certificates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cert_id         TEXT UNIQUE,
  asset_id        TEXT,
  inspection_type TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id         TEXT PRIMARY KEY,
  asset_id   TEXT,
  task       TEXT,
  type       TEXT,
  priority   TEXT,
  freq       INTEGER,
  last_done  DATE,
  next_due   DATE,
  tech       TEXT,
  hours      NUMERIC(8,2),
  cost       NUMERIC(12,2),
  status     TEXT,
  alert_days INTEGER,
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  schedule_id     TEXT,
  completion_date DATE,
  performed_by    TEXT,
  hours           NUMERIC(8,2),
  cost            NUMERIC(12,2),
  parts_used      TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS transfers (
  id         TEXT PRIMARY KEY,
  asset_id   TEXT,
  status     TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS app_users (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT,
  role       TEXT DEFAULT 'Viewer',
  email      TEXT,
  active     BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inspections (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS workshops (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workshop_id TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
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

-- ============================================================
-- 2) Add missing columns only (non-breaking)
-- ============================================================

ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active';
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS rig_name TEXT;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS serial TEXT;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS last_inspection DATE;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS inspection_type TEXT;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS cert_link TEXT;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS acquisition_date DATE;
ALTER TABLE IF EXISTS assets ADD COLUMN IF NOT EXISTS value NUMERIC(14,2) DEFAULT 0;

ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS type TEXT;
ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS depth TEXT;
ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS hp INTEGER;
ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active';
ALTER TABLE IF EXISTS rigs ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS contracts ADD COLUMN IF NOT EXISTS rig TEXT;
ALTER TABLE IF EXISTS contracts ADD COLUMN IF NOT EXISTS value NUMERIC(14,2) DEFAULT 0;
ALTER TABLE IF EXISTS contracts ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE IF EXISTS contracts ADD COLUMN IF NOT EXISTS end_date DATE;
ALTER TABLE IF EXISTS contracts ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Pending';
ALTER TABLE IF EXISTS contracts ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS contract_assets ADD COLUMN IF NOT EXISTS contract_id TEXT;
ALTER TABLE IF EXISTS contract_assets ADD COLUMN IF NOT EXISTS asset_id TEXT;

ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS bom_id TEXT;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS asset_id TEXT;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS parent_id TEXT;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS part_no TEXT;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'Serialized';
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS serial TEXT;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS manufacturer TEXT;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS qty INTEGER DEFAULT 1;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS uom TEXT DEFAULT 'EA';
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS unit_cost NUMERIC(12,2) DEFAULT 0;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS lead_time INTEGER DEFAULT 0;
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active';
ALTER TABLE IF EXISTS bom_items ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS cert_id TEXT;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS asset_id TEXT;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS inspection_type TEXT;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS last_inspection DATE;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS next_inspection DATE;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS validity_days INTEGER DEFAULT 365;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS alert_days INTEGER DEFAULT 30;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS cert_link TEXT;
ALTER TABLE IF EXISTS certificates ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS asset_id TEXT;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS task TEXT;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'Inspection';
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'Normal';
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS freq INTEGER DEFAULT 90;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS last_done DATE;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS next_due DATE;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS tech TEXT;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS hours NUMERIC(8,2);
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS cost NUMERIC(12,2);
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Scheduled';
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS alert_days INTEGER DEFAULT 14;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE IF EXISTS maintenance_schedules ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS maintenance_logs ADD COLUMN IF NOT EXISTS schedule_id TEXT;
ALTER TABLE IF EXISTS maintenance_logs ADD COLUMN IF NOT EXISTS completion_date DATE;
ALTER TABLE IF EXISTS maintenance_logs ADD COLUMN IF NOT EXISTS performed_by TEXT;
ALTER TABLE IF EXISTS maintenance_logs ADD COLUMN IF NOT EXISTS hours NUMERIC(8,2);
ALTER TABLE IF EXISTS maintenance_logs ADD COLUMN IF NOT EXISTS cost NUMERIC(12,2);
ALTER TABLE IF EXISTS maintenance_logs ADD COLUMN IF NOT EXISTS parts_used TEXT;
ALTER TABLE IF EXISTS maintenance_logs ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS asset_name TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS current_loc TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS destination TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS dest_rig TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS priority TEXT DEFAULT 'Normal';
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'Field to Field';
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS requested_by TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS request_date DATE;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS required_date DATE;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS reason TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS instructions TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS vendor_name TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS vendor_type TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS po_number TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS vendor_contact TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS return_date DATE;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS bom_item_id TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS bom_item_name TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS bom_part_no TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS supt_approved_by TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS supt_approved_date DATE;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS supt_action TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS supt_comment TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS ops_approved_by TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS ops_approved_date DATE;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS ops_action TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS ops_comment TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS mgr_approved_by TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS mgr_approved_date DATE;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS mgr_action TEXT;
ALTER TABLE IF EXISTS transfers ADD COLUMN IF NOT EXISTS mgr_comment TEXT;

ALTER TABLE IF EXISTS app_users ADD COLUMN IF NOT EXISTS dept TEXT;
ALTER TABLE IF EXISTS app_users ADD COLUMN IF NOT EXISTS color TEXT;
ALTER TABLE IF EXISTS app_users ADD COLUMN IF NOT EXISTS initials TEXT;
ALTER TABLE IF EXISTS app_users ADD COLUMN IF NOT EXISTS password TEXT;
ALTER TABLE IF EXISTS app_users ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT TRUE;

ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS reg_id TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS inspection_type TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS rig_name TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS asset_id TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS inspected_by TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS due_date DATE;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS status TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS findings TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS recommendation TEXT;
ALTER TABLE IF EXISTS inspections ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS project_id TEXT;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS rig_name TEXT;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS status TEXT;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS priority TEXT;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS end_date DATE;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS budget NUMERIC(14,2);
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS spent NUMERIC(14,2);
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS manager TEXT;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE IF EXISTS projects ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS workshop_name TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS assigned_rig TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS asset_id TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS asset_name TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS asset_serial TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS scope_of_work TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS end_date DATE;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active';
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS technician TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS contact TEXT;
ALTER TABLE IF EXISTS workshops ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS icon TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS type TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE IF EXISTS notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;

-- ============================================================
-- 3) Legacy compatibility backfills (safe)
-- ============================================================

-- If legacy maintenance table exists, backfill maintenance_schedules.
DO $$
BEGIN
  IF to_regclass('public.maintenance') IS NOT NULL THEN
    INSERT INTO maintenance_schedules (
      id, asset_id, task, type, priority, freq, last_done, next_due, tech, hours, cost, status, alert_days, notes
    )
    SELECT
      COALESCE(NULLIF(m.sched_id, ''), 'PM-' || RIGHT(md5(m.id::text), 8)) AS id,
      m.asset_id,
      m.task,
      m.type,
      m.priority,
      COALESCE(m.freq_days, 90) AS freq,
      m.last_done,
      m.next_due,
      m.technician,
      m.hours,
      m.cost,
      CASE WHEN m.status IN ('Overdue','Due Soon') THEN 'Scheduled' ELSE COALESCE(m.status,'Scheduled') END,
      COALESCE(m.alert_days, 14),
      m.notes
    FROM maintenance m
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- If legacy columns exist on maintenance_schedules, backfill modern ones.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='maintenance_schedules' AND column_name='freq_days'
  ) THEN
    EXECUTE 'UPDATE maintenance_schedules SET freq = COALESCE(freq, freq_days, 90)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='maintenance_schedules' AND column_name='technician'
  ) THEN
    EXECUTE 'UPDATE maintenance_schedules SET tech = COALESCE(tech, technician)';
  END IF;
END $$;

UPDATE maintenance_schedules
SET status = 'Scheduled'
WHERE status IN ('Overdue', 'Due Soon');

-- ============================================================
-- 4) Non-breaking constraints/indexes
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'maintenance_schedules_status_chk'
  ) THEN
    ALTER TABLE maintenance_schedules
      ADD CONSTRAINT maintenance_schedules_status_chk
      CHECK (status IN ('Scheduled','In Progress','Completed','Cancelled','Overdue','Due Soon')) NOT VALID;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_assets_asset_id ON assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_assets_rig_name ON assets(rig_name);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets(status);
CREATE INDEX IF NOT EXISTS idx_bom_items_asset_id ON bom_items(asset_id);
CREATE INDEX IF NOT EXISTS idx_certificates_asset_id ON certificates(asset_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_asset_id ON maintenance_schedules(asset_id);
CREATE INDEX IF NOT EXISTS idx_maint_sched_next_due ON maintenance_schedules(next_due);
CREATE INDEX IF NOT EXISTS idx_maint_logs_schedule_id ON maintenance_logs(schedule_id);
CREATE INDEX IF NOT EXISTS idx_transfers_asset_id ON transfers(asset_id);
CREATE INDEX IF NOT EXISTS idx_transfers_status ON transfers(status);
CREATE INDEX IF NOT EXISTS idx_projects_project_id ON projects(project_id);
CREATE INDEX IF NOT EXISTS idx_workshops_workshop_id ON workshops(workshop_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_contract_assets_contract_id ON contract_assets(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_assets_asset_id ON contract_assets(asset_id);

COMMIT;

