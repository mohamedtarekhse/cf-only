-- ============================================================
--  004_inspections_add_rig.sql  —  Run in Supabase SQL Editor
--  Adds rig_name column to inspections table
-- ============================================================

ALTER TABLE inspections
  ADD COLUMN IF NOT EXISTS rig_name TEXT;

CREATE INDEX IF NOT EXISTS idx_inspections_rig ON inspections (rig_name);
