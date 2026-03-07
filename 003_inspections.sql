-- ============================================================
--  003_inspections.sql  —  Run in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS inspections (
  id               BIGSERIAL PRIMARY KEY,
  start_date       DATE          NOT NULL,
  end_date         DATE,
  company          TEXT,
  inspection_type  TEXT          CHECK (inspection_type IN (
                     'Cat IV','Annual Inspection','6-Month Inspection',
                     'Quarterly Inspection','Monthly Inspection','Weekly Inspection',
                     'Bi-Weekly Inspection','Load Test','BOP Pressure Test',
                     'Calibration','Pressure Test','UT NDT Inspection'
                   )),
  cost_per_day     NUMERIC(12,2) DEFAULT 0,
  total_cost       NUMERIC(14,2) DEFAULT 0,
  po_number        TEXT,
  service_order    TEXT,
  notes            TEXT,
  created_at       TIMESTAMPTZ   DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION update_updated_at_inspections()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inspections_updated_at ON inspections;
CREATE TRIGGER trg_inspections_updated_at
  BEFORE UPDATE ON inspections
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_inspections();

CREATE INDEX IF NOT EXISTS idx_inspections_company ON inspections (company);
CREATE INDEX IF NOT EXISTS idx_inspections_type    ON inspections (inspection_type);
CREATE INDEX IF NOT EXISTS idx_inspections_start   ON inspections (start_date DESC);

ALTER TABLE inspections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "inspections_all" ON inspections;
CREATE POLICY "inspections_all" ON inspections FOR ALL USING (true) WITH CHECK (true);
