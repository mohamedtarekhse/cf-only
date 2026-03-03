-- ══════════════════════════════════════════════════════════════════════════════
--  Asset Management System — Schema (Simplest working version)
--  Run in Supabase SQL Editor → New Query → Run
--
--  Design decisions:
--  • No ENUMs — plain TEXT, simpler to modify
--  • RLS DISABLED — auth is x-api-key at Express layer
--  • No FK on assets.company / assets.rig_name — prevents silent update failures
--  • updated_at auto-trigger on every mutable table
-- ══════════════════════════════════════════════════════════════════════════════

-- ─── COMPANIES ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS companies (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL UNIQUE,
  type       TEXT DEFAULT 'Drilling Contractor',
  country    TEXT,
  contact    TEXT,
  email      TEXT,
  status     TEXT DEFAULT 'Active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── RIGS ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rigs (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL UNIQUE,
  type       TEXT,
  company    TEXT,   -- plain TEXT, no FK
  location   TEXT,
  depth      TEXT,
  hp         INTEGER,
  status     TEXT DEFAULT 'Active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── CONTRACTS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contracts (
  id         TEXT PRIMARY KEY,
  company    TEXT,   -- plain TEXT, no FK
  rig        TEXT,
  value      NUMERIC(15,2) DEFAULT 0,
  start_date DATE,
  end_date   DATE,
  status     TEXT DEFAULT 'Pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── ASSETS ───────────────────────────────────────────────────────────────────
-- company + rig_name are plain TEXT — no FK constraints.
-- FK constraints were causing silent UPDATE failures when values didn't
-- match exactly (spaces, case differences, etc.)
CREATE TABLE IF NOT EXISTS assets (
  asset_id         TEXT PRIMARY KEY,
  name             TEXT NOT NULL,
  category         TEXT DEFAULT 'Other',
  company          TEXT,   -- plain TEXT, no FK
  rig_name         TEXT,   -- plain TEXT, no FK
  location         TEXT,
  status           TEXT DEFAULT 'Active',
  value            NUMERIC(15,2) DEFAULT 0,
  acquisition_date DATE,
  serial           TEXT,
  notes            TEXT,
  last_inspection  DATE,
  inspection_type  TEXT,
  cert_link        TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ─── CONTRACT ↔ ASSET ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contract_assets (
  contract_id TEXT REFERENCES contracts(id) ON DELETE CASCADE,
  asset_id    TEXT REFERENCES assets(asset_id) ON DELETE CASCADE,
  PRIMARY KEY (contract_id, asset_id)
);

-- ─── BOM ITEMS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bom_items (
  id           TEXT PRIMARY KEY,
  asset_id     TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  parent_id    TEXT REFERENCES bom_items(id) ON DELETE SET NULL,
  name         TEXT NOT NULL,
  part_no      TEXT,
  type         TEXT DEFAULT 'Serialized',
  serial       TEXT,
  manufacturer TEXT,
  qty          NUMERIC(10,3) DEFAULT 1,
  uom          TEXT DEFAULT 'EA',
  unit_cost    NUMERIC(15,2) DEFAULT 0,
  lead_time    INTEGER DEFAULT 0,
  status       TEXT DEFAULT 'Active',
  notes        TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ─── CERTIFICATES ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS certificates (
  cert_id         TEXT PRIMARY KEY,
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

-- ─── MAINTENANCE SCHEDULES ────────────────────────────────────────────────────
-- status stores ONLY: Scheduled / In Progress / Completed / Cancelled
-- 'Overdue' and 'Due Soon' are COMPUTED by the API — never stored
CREATE TABLE IF NOT EXISTS maintenance_schedules (
  id         TEXT PRIMARY KEY,
  asset_id   TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  task       TEXT NOT NULL,
  type       TEXT DEFAULT 'Inspection',
  priority   TEXT DEFAULT 'Normal',
  freq       INTEGER DEFAULT 90,
  last_done  DATE,
  next_due   DATE NOT NULL,
  tech       TEXT,
  hours      NUMERIC(6,2),
  cost       NUMERIC(12,2),
  status     TEXT DEFAULT 'Scheduled',
  alert_days INTEGER DEFAULT 14,
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── MAINTENANCE LOGS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS maintenance_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id     TEXT NOT NULL REFERENCES maintenance_schedules(id) ON DELETE CASCADE,
  completion_date DATE NOT NULL,
  performed_by    TEXT NOT NULL,
  hours           NUMERIC(6,2),
  cost            NUMERIC(12,2),
  parts_used      TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TRANSFERS ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transfers (
  id                TEXT PRIMARY KEY,
  asset_id          TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE RESTRICT,
  asset_name        TEXT,
  current_loc       TEXT,
  destination       TEXT NOT NULL,
  dest_rig          TEXT,
  dest_company      TEXT,
  priority          TEXT DEFAULT 'Normal',
  type              TEXT DEFAULT 'Field to Field',
  requested_by      TEXT,
  request_date      DATE DEFAULT CURRENT_DATE,
  required_date     DATE,
  reason            TEXT,
  instructions      TEXT,
  status            TEXT DEFAULT 'Pending',
  ops_approved_by   TEXT,
  ops_approved_date DATE,
  ops_action        TEXT,
  ops_comment       TEXT,
  mgr_approved_by   TEXT,
  mgr_approved_date DATE,
  mgr_action        TEXT,
  mgr_comment       TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ─── USERS ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app_users (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  role       TEXT DEFAULT 'Viewer',
  dept       TEXT,
  email      TEXT UNIQUE NOT NULL,
  color      TEXT DEFAULT '#0070F2',
  initials   TEXT,
  active     BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  icon        TEXT DEFAULT 'fas fa-info-circle',
  kind        TEXT DEFAULT 'info',
  title       TEXT NOT NULL,
  description TEXT,
  time_label  TEXT,
  is_read     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── AUTO updated_at TRIGGER ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'companies','rigs','contracts','assets','bom_items',
    'certificates','maintenance_schedules','transfers','app_users'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_upd ON %I;
       CREATE TRIGGER trg_upd BEFORE UPDATE ON %I
       FOR EACH ROW EXECUTE FUNCTION set_updated_at();', t, t);
  END LOOP;
END $$;

-- ─── DISABLE RLS (auth handled at Express API layer) ──────────────────────────
ALTER TABLE companies             DISABLE ROW LEVEL SECURITY;
ALTER TABLE rigs                  DISABLE ROW LEVEL SECURITY;
ALTER TABLE contracts             DISABLE ROW LEVEL SECURITY;
ALTER TABLE assets                DISABLE ROW LEVEL SECURITY;
ALTER TABLE contract_assets       DISABLE ROW LEVEL SECURITY;
ALTER TABLE bom_items             DISABLE ROW LEVEL SECURITY;
ALTER TABLE certificates          DISABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_schedules DISABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_logs      DISABLE ROW LEVEL SECURITY;
ALTER TABLE transfers             DISABLE ROW LEVEL SECURITY;
ALTER TABLE app_users             DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications         DISABLE ROW LEVEL SECURITY;

-- ─── GRANTS ───────────────────────────────────────────────────────────────────
DO $$ DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'companies','rigs','contracts','assets','contract_assets','bom_items',
    'certificates','maintenance_schedules','maintenance_logs',
    'transfers','app_users','notifications'
  ] LOOP
    EXECUTE format(
      'GRANT SELECT,INSERT,UPDATE,DELETE ON %I TO anon, authenticated;', t);
  END LOOP;
END $$;
