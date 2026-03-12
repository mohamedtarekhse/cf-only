-- Fix maintenance_schedules schema to match app/worker payloads
-- Safe to run multiple times.

BEGIN;

-- Ensure table exists (minimal definition used by the app)
CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id           TEXT PRIMARY KEY,
  asset_id     TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  task         TEXT NOT NULL,
  type         TEXT DEFAULT 'Inspection',
  priority     TEXT DEFAULT 'Normal',
  freq         INTEGER DEFAULT 90,
  last_done    DATE,
  next_due     DATE,
  tech         TEXT,
  hours        NUMERIC(8,2),
  cost         NUMERIC(10,2),
  status       TEXT DEFAULT 'Scheduled',
  alert_days   INTEGER DEFAULT 14,
  notes        TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns expected by the app
ALTER TABLE maintenance_schedules ADD COLUMN IF NOT EXISTS freq INTEGER;
ALTER TABLE maintenance_schedules ADD COLUMN IF NOT EXISTS tech TEXT;
ALTER TABLE maintenance_schedules ADD COLUMN IF NOT EXISTS alert_days INTEGER;
ALTER TABLE maintenance_schedules ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Backfill freq from legacy freq_days if that column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_schedules'
      AND column_name = 'freq_days'
  ) THEN
    EXECUTE 'UPDATE maintenance_schedules SET freq = COALESCE(freq, freq_days, 90)';
  ELSE
    UPDATE maintenance_schedules SET freq = COALESCE(freq, 90);
  END IF;
END $$;

-- Backfill tech from legacy technician if that column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'maintenance_schedules'
      AND column_name = 'technician'
  ) THEN
    EXECUTE 'UPDATE maintenance_schedules SET tech = COALESCE(tech, technician)';
  END IF;
END $$;

-- Defaults used by frontend/worker
ALTER TABLE maintenance_schedules ALTER COLUMN freq SET DEFAULT 90;
ALTER TABLE maintenance_schedules ALTER COLUMN alert_days SET DEFAULT 14;

-- Optional hardening: keep status values aligned with UI/worker
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'maintenance_schedules_status_chk'
  ) THEN
    ALTER TABLE maintenance_schedules
      ADD CONSTRAINT maintenance_schedules_status_chk
      CHECK (status IN ('Scheduled','In Progress','Completed','Cancelled','Overdue','Due Soon'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_asset_id ON maintenance_schedules(asset_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_schedules_next_due ON maintenance_schedules(next_due);

COMMIT;
