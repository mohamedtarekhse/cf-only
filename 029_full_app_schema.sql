-- Bring the database schema in line with the payload keys currently sent by index.html.
-- Safe to run multiple times.

BEGIN;

ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS priority TEXT,
  ADD COLUMN IF NOT EXISTS rig_name TEXT,
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS manager TEXT,
  ADD COLUMN IF NOT EXISTS supervisor_name TEXT,
  ADD COLUMN IF NOT EXISTS supervisor_contact TEXT,
  ADD COLUMN IF NOT EXISTS initiation_date DATE,
  ADD COLUMN IF NOT EXISTS start_date DATE,
  ADD COLUMN IF NOT EXISTS end_date DATE,
  ADD COLUMN IF NOT EXISTS progress INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS notes TEXT;

ALTER TABLE inspections
  ADD COLUMN IF NOT EXISTS po_number TEXT,
  ADD COLUMN IF NOT EXISTS service_order TEXT,
  ADD COLUMN IF NOT EXISTS start_date DATE,
  ADD COLUMN IF NOT EXISTS rig_name TEXT,
  ADD COLUMN IF NOT EXISTS inspection_type TEXT,
  ADD COLUMN IF NOT EXISTS end_date DATE,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS cost_per_day NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_cost NUMERIC(12,2) NOT NULL DEFAULT 0;

-- Document the current UI/server contract from index.html:
--   projects payload keys:
--     project_id, description, status, priority, rig_name, location, manager,
--     supervisor_name, supervisor_contact, initiation_date, start_date,
--     end_date, progress, notes
--   inspections payload keys:
--     po_number, service_order, start_date, rig_name, inspection_type,
--     end_date, notes
--   inspections mass-edit payload also persists:
--     cost_per_day, total_cost

ALTER TABLE projects
  DROP CONSTRAINT IF EXISTS projects_progress_check;
ALTER TABLE projects
  ADD CONSTRAINT projects_progress_check
  CHECK (progress BETWEEN 0 AND 100);

COMMIT;
