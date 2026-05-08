-- =============================================================================
-- Projects / inspections schema alignment
--
-- Aligns the database tables with the frontend payloads used by index.html for
-- project save/edit flows and inspection save/edit/bulk-edit flows.
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- Projects
-- Frontend payload keys reviewed:
--   project_id, description, status, priority, rig_name, location, manager,
--   supervisor_name, supervisor_contact, initiation_date, start_date,
--   end_date, progress, notes
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS projects (
  project_id          TEXT PRIMARY KEY,
  description         TEXT NOT NULL DEFAULT '',
  status              TEXT NOT NULL DEFAULT 'Planning'
                        CHECK (status IN ('Planning','Active','On Hold','Completed','Cancelled')),
  priority            TEXT NOT NULL DEFAULT 'Normal'
                        CHECK (priority IN ('Critical','High','Normal','Low')),
  rig_name            TEXT,
  location            TEXT,
  manager             TEXT,
  supervisor_name     TEXT,
  supervisor_contact  TEXT,
  initiation_date     DATE,
  start_date          DATE,
  end_date            DATE,
  progress            INTEGER NOT NULL DEFAULT 0
                        CHECK (progress >= 0 AND progress <= 100),
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE IF EXISTS projects
  ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'Planning',
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'Normal',
  ADD COLUMN IF NOT EXISTS rig_name TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS manager TEXT,
  ADD COLUMN IF NOT EXISTS supervisor_name TEXT,
  ADD COLUMN IF NOT EXISTS supervisor_contact TEXT,
  ADD COLUMN IF NOT EXISTS initiation_date DATE,
  ADD COLUMN IF NOT EXISTS start_date DATE,
  ADD COLUMN IF NOT EXISTS end_date DATE,
  ADD COLUMN IF NOT EXISTS progress INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_projects_status    ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_priority  ON projects(priority);
CREATE INDEX IF NOT EXISTS idx_projects_rig_name  ON projects(rig_name);
CREATE INDEX IF NOT EXISTS idx_projects_location  ON projects(location);

-- ─────────────────────────────────────────────────────────────────────────────
-- Inspections
-- Frontend payload keys reviewed:
--   save/edit: po_number, service_order, start_date, rig_name,
--              inspection_type, end_date, notes
--   bulk edit: inspection_type, po_number, service_order, cost_per_day,
--              total_cost, start_date, end_date, notes
--   frontend row normalization / display also expects: inspected_by, location
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inspections (
  id                  TEXT PRIMARY KEY,
  po_number           TEXT,
  service_order       TEXT,
  inspected_by        TEXT,
  start_date          DATE,
  rig_name            TEXT,
  location            TEXT,
  end_date            DATE,
  inspection_type     TEXT,
  cost_per_day        NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_cost          NUMERIC(14,2) NOT NULL DEFAULT 0,
  notes               TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE IF EXISTS inspections
  ADD COLUMN IF NOT EXISTS po_number TEXT,
  ADD COLUMN IF NOT EXISTS service_order TEXT,
  ADD COLUMN IF NOT EXISTS inspected_by TEXT,
  ADD COLUMN IF NOT EXISTS start_date DATE,
  ADD COLUMN IF NOT EXISTS rig_name TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS end_date DATE,
  ADD COLUMN IF NOT EXISTS inspection_type TEXT,
  ADD COLUMN IF NOT EXISTS cost_per_day NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_cost NUMERIC(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_inspections_start_date      ON inspections(start_date);
CREATE INDEX IF NOT EXISTS idx_inspections_inspection_type ON inspections(inspection_type);
CREATE INDEX IF NOT EXISTS idx_inspections_rig_name        ON inspections(rig_name);
CREATE INDEX IF NOT EXISTS idx_inspections_location        ON inspections(location);

COMMIT;
