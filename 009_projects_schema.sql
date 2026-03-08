-- ============================================================
--  009_projects_schema.sql
--  Projects table: create (if new) OR migrate (if existing)
--
--  Changes vs previous shape:
--    • REMOVED  : budget, spent
--    • RENAMED  : name → description
--    • ADDED    : supervisor_name, supervisor_contact, initiation_date
-- ============================================================

-- ── 1. Create table if it doesn't exist yet ─────────────────
CREATE TABLE IF NOT EXISTS projects (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id          TEXT        NOT NULL UNIQUE,
  description         TEXT        NOT NULL,
  status              TEXT        DEFAULT 'Planning'
                                    CHECK (status IN ('Planning','Active','On Hold','Completed','Cancelled')),
  priority            TEXT        DEFAULT 'Normal'
                                    CHECK (priority IN ('Critical','High','Normal','Low')),
  rig_name            TEXT,
  location            TEXT,
  manager             TEXT,
  supervisor_name     TEXT,
  supervisor_contact  TEXT,
  initiation_date     DATE,
  start_date          DATE,
  end_date            DATE,
  progress            INTEGER     DEFAULT 0 CHECK (progress BETWEEN 0 AND 100),
  notes               TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);


-- ── 2. Migrate existing table (safe — all IF EXISTS / IF NOT EXISTS) ──

-- Rename 'name' to 'description' if the old column still exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'projects' AND column_name = 'name'
  ) THEN
    -- Copy data then drop old column (safer than ALTER TABLE RENAME in Supabase)
    ALTER TABLE projects ADD COLUMN IF NOT EXISTS description TEXT;
    UPDATE projects SET description = name WHERE description IS NULL;
    ALTER TABLE projects DROP COLUMN name;
  END IF;
END;
$$;

-- Drop budget and spent if they exist
ALTER TABLE projects DROP COLUMN IF EXISTS budget;
ALTER TABLE projects DROP COLUMN IF EXISTS spent;

-- Add new columns
ALTER TABLE projects ADD COLUMN IF NOT EXISTS supervisor_name    TEXT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS supervisor_contact TEXT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS initiation_date    DATE;


-- ── 3. Indexes ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_projects_status   ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_rig_name ON projects(rig_name);
CREATE INDEX IF NOT EXISTS idx_projects_priority ON projects(priority);


-- ── 4. updated_at trigger ────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_projects_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_projects_updated_at ON projects;
CREATE TRIGGER trg_projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION fn_projects_updated_at();


-- ── 5. RLS ───────────────────────────────────────────────────
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS allow_authenticated ON projects;
CREATE POLICY allow_authenticated ON projects
  FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ── 6. Verify ────────────────────────────────────────────────
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'projects'
ORDER BY ordinal_position;
