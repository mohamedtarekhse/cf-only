-- ============================================================
--  ASSET MANAGEMENT SYSTEM — Supabase / PostgreSQL Schema
--  Land Rig & Contracting
--  
--  INCLUDES:
--    1. Core tables (assets, rigs, companies, contracts, etc.)
--    2. NEW category-specific equipment tables
--    3. Trigger: auto-inserts into category table on asset save
--    4. Register tables (BOP, Well Head, Well Control, 
--       Fire Extinguisher, SCBA)
-- ============================================================

-- ────────────────────────────────────────────────────────────
--  EXTENSIONS
-- ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";


-- ============================================================
--  SECTION 1 — CORE TABLES
-- ============================================================



-- ── Land Rigs ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rigs (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  rig_name      TEXT NOT NULL UNIQUE,
  rig_type      TEXT,
  location      TEXT,
  status        TEXT DEFAULT 'Active'
                  CHECK (status IN ('Active','Idle','Maintenance','Retired')),
  hp            INTEGER,
  depth_rating  INTEGER,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Contracts ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS contracts (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contract_id   TEXT NOT NULL UNIQUE,
  rig_id        UUID REFERENCES rigs(id) ON DELETE SET NULL,
  start_date    DATE,
  end_date      DATE,
  value         NUMERIC(14,2) DEFAULT 0,
  status        TEXT DEFAULT 'Active'
                  CHECK (status IN ('Active','Expired','Pending','Terminated')),
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Assets (master table) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS assets (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id         TEXT NOT NULL UNIQUE,
  name             TEXT NOT NULL,
  category         TEXT NOT NULL,
  status           TEXT DEFAULT 'Active'
                     CHECK (status IN ('Active','Maintenance','Inactive','Contracted','Retired')),
  rig_name         TEXT,
  location         TEXT,
  serial           TEXT,
  value            NUMERIC(14,2) DEFAULT 0,
  acquisition_date DATE,
  last_inspection  DATE,
  inspection_type  TEXT,
  cert_link        TEXT,
  notes            TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assets_category ON assets(category);
CREATE INDEX IF NOT EXISTS idx_assets_status   ON assets(status);
CREATE INDEX IF NOT EXISTS idx_assets_rig_name ON assets(rig_name);

-- ── Bill of Materials ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS bom_items (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bom_id       TEXT NOT NULL UNIQUE,
  asset_id     TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
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
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── Maintenance Schedules ───────────────────────────────────
CREATE TABLE IF NOT EXISTS maintenance (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sched_id   TEXT NOT NULL UNIQUE,
  asset_id   TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  task       TEXT NOT NULL,
  type       TEXT DEFAULT 'Inspection',
  priority   TEXT DEFAULT 'Normal',
  freq_days  INTEGER DEFAULT 90,
  last_done  DATE,
  next_due   DATE NOT NULL,
  technician TEXT,
  hours      NUMERIC(8,2),
  cost       NUMERIC(10,2),
  status     TEXT DEFAULT 'Scheduled'
               CHECK (status IN ('Scheduled','In Progress','Completed','Overdue','Cancelled')),
  alert_days INTEGER DEFAULT 14,
  notes      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Certificates ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS certificates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cert_id         TEXT NOT NULL UNIQUE,
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

-- ── Asset Transfers ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transfers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transfer_id     TEXT NOT NULL UNIQUE,
  asset_id        TEXT NOT NULL REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name      TEXT,
  current_loc     TEXT,
  destination     TEXT,
  dest_rig        TEXT,
  priority        TEXT DEFAULT 'Normal',
  type            TEXT DEFAULT 'Field to Field',
  requested_by    TEXT,
  request_date    DATE,
  required_date   DATE,
  reason          TEXT,
  instructions    TEXT,
  status          TEXT DEFAULT 'Pending'
                    CHECK (status IN ('Pending','Approved','In Transit','Completed','Cancelled')),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── Users ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email      TEXT NOT NULL UNIQUE,
  name       TEXT NOT NULL,
  role       TEXT DEFAULT 'Viewer',
  dept       TEXT,
  color      TEXT DEFAULT '#0070F2',
  initials   TEXT,
  password   TEXT,
  active     BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
--  SECTION 2 — CATEGORY-SPECIFIC EQUIPMENT TABLES
--  Auto-populated via trigger when an asset is created/updated
--  with a matching category value.
-- ============================================================

-- ── Safety Equipment ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_safety_equipment (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id     TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name   TEXT,
  serial       TEXT,
  rig_name     TEXT,
  location     TEXT,
  status       TEXT,
  -- Safety-specific fields
  safety_class TEXT,                    -- e.g. Class A, B, C
  rating       TEXT,                    -- e.g. ATEX Zone 1
  last_service DATE,
  next_service DATE,
  notes        TEXT,
  synced_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Generators ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_generators (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id      TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name    TEXT,
  serial        TEXT,
  rig_name      TEXT,
  location      TEXT,
  status        TEXT,
  -- Generator-specific fields
  power_kva     NUMERIC(10,2),          -- rated output in KVA
  voltage_v     NUMERIC(8,2),           -- output voltage
  frequency_hz  NUMERIC(6,2),           -- Hz
  fuel_type     TEXT,                   -- Diesel, Gas, Dual
  engine_model  TEXT,
  run_hours     NUMERIC(10,2) DEFAULT 0,
  last_service  DATE,
  next_service  DATE,
  notes         TEXT,
  synced_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ── Agitators ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_agitators (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id     TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name   TEXT,
  serial        TEXT,
  rig_name     TEXT,
  location     TEXT,
  status       TEXT,
  -- Agitator-specific fields
  motor_hp     NUMERIC(8,2),            -- horsepower
  rpm          INTEGER,
  tank_size_m3 NUMERIC(8,2),            -- tank volume
  blade_type   TEXT,
  last_service DATE,
  next_service DATE,
  notes        TEXT,
  synced_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Compressors ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_compressors (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id       TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name     TEXT,
  serial         TEXT,
  rig_name       TEXT,
  location       TEXT,
  status         TEXT,
  -- Compressor-specific fields
  type           TEXT,                  -- Reciprocating, Screw, Centrifugal
  capacity_cfm   NUMERIC(10,2),         -- cubic feet per minute
  max_pressure   NUMERIC(8,2),          -- PSI
  power_hp       NUMERIC(8,2),
  stage          TEXT,                  -- Single / Two-Stage
  run_hours      NUMERIC(10,2) DEFAULT 0,
  last_service   DATE,
  next_service   DATE,
  notes          TEXT,
  synced_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ── Engines ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_engines (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id     TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name   TEXT,
  serial       TEXT,
  rig_name     TEXT,
  location     TEXT,
  status       TEXT,
  -- Engine-specific fields
  engine_type  TEXT,                    -- Diesel, Gas, Dual-Fuel
  power_hp     NUMERIC(10,2),
  cylinders    INTEGER,
  displacement TEXT,                    -- e.g. 15L
  fuel_type    TEXT,
  run_hours    NUMERIC(10,2) DEFAULT 0,
  last_service DATE,
  next_service DATE,
  notes        TEXT,
  synced_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── AC Motors ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_ac_motors (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id     TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name   TEXT,
  serial       TEXT,
  rig_name     TEXT,
  location     TEXT,
  status       TEXT,
  -- AC Motor-specific fields
  power_kw     NUMERIC(10,2),
  voltage_v    NUMERIC(8,2),
  amperage_a   NUMERIC(8,2),
  frequency_hz NUMERIC(6,2),
  rpm          INTEGER,
  frame_size   TEXT,                    -- IEC / NEMA frame
  insulation   TEXT,                    -- Class F, H, etc.
  ip_rating    TEXT,                    -- IP55, IP65, etc.
  last_service DATE,
  next_service DATE,
  notes        TEXT,
  synced_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── Centrifugal Pumps ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_centrifugal_pumps (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id        TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name      TEXT,
  serial          TEXT,
  rig_name        TEXT,
  location        TEXT,
  status          TEXT,
  -- Pump-specific fields
  flow_rate_gpm   NUMERIC(10,2),        -- gallons per minute
  head_ft         NUMERIC(10,2),        -- total dynamic head in feet
  power_hp        NUMERIC(8,2),
  discharge_size  TEXT,                 -- e.g. 3 inch
  suction_size    TEXT,
  fluid_type      TEXT,                 -- Mud, Water, Chemical
  impeller_dia_mm NUMERIC(8,2),
  run_hours       NUMERIC(10,2) DEFAULT 0,
  last_service    DATE,
  next_service    DATE,
  notes           TEXT,
  synced_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── Drilling Equipment ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_drilling_equipment (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id        TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name      TEXT,
  serial          TEXT,
  rig_name        TEXT,
  location        TEXT,
  status          TEXT,
  -- Drilling-specific fields
  equipment_type  TEXT,                 -- Top Drive, Rotary Table, Kelly, etc.
  api_spec        TEXT,                 -- applicable API spec
  pressure_rating TEXT,                 -- PSI rating
  size_inches     NUMERIC(6,2),
  max_wob_klbs    NUMERIC(8,2),         -- max weight on bit (klbs)
  torque_rating   TEXT,
  last_inspection DATE,
  next_inspection DATE,
  notes           TEXT,
  synced_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── Hoisting Equipment ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_hoisting_equipment (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id        TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name      TEXT,
  serial          TEXT,
  rig_name        TEXT,
  location        TEXT,
  status          TEXT,
  -- Hoisting-specific fields
  equipment_type  TEXT,                 -- Crown Block, Travelling Block, Hook, etc.
  load_rating_ton NUMERIC(10,2),        -- rated load in tons
  wire_rope_dia   NUMERIC(6,2),         -- inches
  lines           INTEGER,              -- number of lines strung
  api_spec        TEXT,
  last_inspection DATE,
  next_inspection DATE,
  notes           TEXT,
  synced_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── Winches ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS eq_winches (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id        TEXT NOT NULL UNIQUE REFERENCES assets(asset_id) ON DELETE CASCADE,
  asset_name      TEXT,
  serial          TEXT,
  rig_name        TEXT,
  location        TEXT,
  status          TEXT,
  -- Winch-specific fields
  winch_type      TEXT,                 -- Tugger, Cathead, Air, Hydraulic, Electric
  line_pull_ton   NUMERIC(8,2),         -- rated line pull in tons
  rope_capacity_m NUMERIC(8,2),         -- rope/wire capacity in metres
  power_source    TEXT,                 -- Air, Hydraulic, Electric, Manual
  drum_diameter   NUMERIC(6,2),         -- mm
  last_inspection DATE,
  next_inspection DATE,
  notes           TEXT,
  synced_at       TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
--  SECTION 3 — REGISTER TABLES
--  (BOP, Well Head, Well Control Equipment, Fire Extinguishers,
--   SCBA) — shared inspection-tracking schema
-- ============================================================

-- Shared helper: inspection status computed column
-- Returns: 'Valid' | 'Expiring Soon' | 'Expired'
CREATE OR REPLACE FUNCTION inspection_status(expiry_date DATE)
RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN expiry_date IS NULL THEN 'Unknown'
    WHEN expiry_date < CURRENT_DATE THEN 'Expired'
    WHEN expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'Expiring Soon'
    ELSE 'Valid'
  END;
$$;

-- ── BOP Register ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reg_bop (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id             TEXT NOT NULL UNIQUE DEFAULT 'BOP-' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
  asset_id           TEXT REFERENCES assets(asset_id) ON DELETE SET NULL,
  asset              TEXT NOT NULL,
  serial_number      TEXT NOT NULL,
  last_inspection    DATE,
  expiry_inspection  DATE,
  assigned_location  TEXT,
  rig                TEXT,
  inspection_status  TEXT GENERATED ALWAYS AS (inspection_status(expiry_inspection)) STORED,
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- ── Well Head Register ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS reg_well_head (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id             TEXT NOT NULL UNIQUE DEFAULT 'WH-' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
  asset_id           TEXT REFERENCES assets(asset_id) ON DELETE SET NULL,
  asset              TEXT NOT NULL,
  serial_number      TEXT NOT NULL,
  last_inspection    DATE,
  expiry_inspection  DATE,
  assigned_location  TEXT,
  rig                TEXT,
  inspection_status  TEXT GENERATED ALWAYS AS (inspection_status(expiry_inspection)) STORED,
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- ── Well Control Equipment Register ─────────────────────────
CREATE TABLE IF NOT EXISTS reg_well_control (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id             TEXT NOT NULL UNIQUE DEFAULT 'WCE-' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
  asset_id           TEXT REFERENCES assets(asset_id) ON DELETE SET NULL,
  asset              TEXT NOT NULL,
  serial_number      TEXT NOT NULL,
  last_inspection    DATE,
  expiry_inspection  DATE,
  assigned_location  TEXT,
  rig                TEXT,
  inspection_status  TEXT GENERATED ALWAYS AS (inspection_status(expiry_inspection)) STORED,
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- ── Fire Extinguisher Register ──────────────────────────────
CREATE TABLE IF NOT EXISTS reg_fire_extinguishers (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id             TEXT NOT NULL UNIQUE DEFAULT 'FE-' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
  asset_id           TEXT REFERENCES assets(asset_id) ON DELETE SET NULL,
  asset              TEXT NOT NULL,
  serial_number      TEXT NOT NULL,
  last_inspection    DATE,
  expiry_inspection  DATE,
  assigned_location  TEXT,
  rig                TEXT,
  inspection_status  TEXT GENERATED ALWAYS AS (inspection_status(expiry_inspection)) STORED,
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- ── SCBA Register ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reg_scba (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  reg_id             TEXT NOT NULL UNIQUE DEFAULT 'SCBA-' || EXTRACT(EPOCH FROM NOW())::BIGINT::TEXT,
  asset_id           TEXT REFERENCES assets(asset_id) ON DELETE SET NULL,
  asset              TEXT NOT NULL,
  serial_number      TEXT NOT NULL,
  last_inspection    DATE,
  expiry_inspection  DATE,
  assigned_location  TEXT,
  rig                TEXT,
  inspection_status  TEXT GENERATED ALWAYS AS (inspection_status(expiry_inspection)) STORED,
  notes              TEXT,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);


-- ============================================================
--  SECTION 4 — AUTO-ROUTING TRIGGER
--  When an asset is INSERT-ed or UPDATE-d and its category
--  matches one of the 9 equipment types, the system
--  automatically upserts a row into the matching table.
--  On DELETE the CASCADE foreign key cleans up automatically.
-- ============================================================

CREATE OR REPLACE FUNCTION fn_route_asset_to_category_table()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN

  -- ── Safety Equipment ──────────────────────────────────────
  IF NEW.category = 'Safety Equipment' THEN
    INSERT INTO eq_safety_equipment
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Generators ───────────────────────────────────────────
  ELSIF NEW.category = 'Generators' THEN
    INSERT INTO eq_generators
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Agitators ─────────────────────────────────────────────
  ELSIF NEW.category = 'Agitators' THEN
    INSERT INTO eq_agitators
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Compressors ───────────────────────────────────────────
  ELSIF NEW.category = 'Compressors' THEN
    INSERT INTO eq_compressors
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Engines ───────────────────────────────────────────────
  ELSIF NEW.category = 'Engines' THEN
    INSERT INTO eq_engines
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── AC Motors ─────────────────────────────────────────────
  ELSIF NEW.category = 'AC Motors' THEN
    INSERT INTO eq_ac_motors
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Centrifugal Pumps ─────────────────────────────────────
  ELSIF NEW.category = 'Centrifugal Pumps' THEN
    INSERT INTO eq_centrifugal_pumps
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Drilling Equipment ────────────────────────────────────
  ELSIF NEW.category = 'Drilling Equipment' THEN
    INSERT INTO eq_drilling_equipment
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Hoisting Equipment ────────────────────────────────────
  ELSIF NEW.category = 'Hoisting Equipment' THEN
    INSERT INTO eq_hoisting_equipment
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  -- ── Winches ───────────────────────────────────────────────
  ELSIF NEW.category = 'Winches' THEN
    INSERT INTO eq_winches
      (asset_id, asset_name, serial, rig_name, location, status, synced_at)
    VALUES
      (NEW.asset_id, NEW.name, NEW.serial, NEW.rig_name, NEW.location, NEW.status, NOW())
    ON CONFLICT (asset_id) DO UPDATE SET
      asset_name = EXCLUDED.asset_name,
      serial     = EXCLUDED.serial,
      rig_name   = EXCLUDED.rig_name,
      location   = EXCLUDED.location,
      status     = EXCLUDED.status,
      synced_at  = NOW();

  END IF;

  -- ── Handle category CHANGE: remove from old table ─────────
  -- If the category was changed, clean up the old category table
  IF TG_OP = 'UPDATE' AND OLD.category IS DISTINCT FROM NEW.category THEN
    CASE OLD.category
      WHEN 'Safety Equipment'   THEN DELETE FROM eq_safety_equipment   WHERE asset_id = OLD.asset_id;
      WHEN 'Generators'         THEN DELETE FROM eq_generators          WHERE asset_id = OLD.asset_id;
      WHEN 'Agitators'          THEN DELETE FROM eq_agitators           WHERE asset_id = OLD.asset_id;
      WHEN 'Compressors'        THEN DELETE FROM eq_compressors         WHERE asset_id = OLD.asset_id;
      WHEN 'Engines'            THEN DELETE FROM eq_engines             WHERE asset_id = OLD.asset_id;
      WHEN 'AC Motors'          THEN DELETE FROM eq_ac_motors           WHERE asset_id = OLD.asset_id;
      WHEN 'Centrifugal Pumps'  THEN DELETE FROM eq_centrifugal_pumps  WHERE asset_id = OLD.asset_id;
      WHEN 'Drilling Equipment' THEN DELETE FROM eq_drilling_equipment  WHERE asset_id = OLD.asset_id;
      WHEN 'Hoisting Equipment' THEN DELETE FROM eq_hoisting_equipment  WHERE asset_id = OLD.asset_id;
      WHEN 'Winches'            THEN DELETE FROM eq_winches             WHERE asset_id = OLD.asset_id;
      ELSE NULL;
    END CASE;
  END IF;

  -- Always update the updated_at timestamp on the asset itself
  NEW.updated_at = NOW();

  RETURN NEW;
END;
$$;

-- Attach trigger to assets table
DROP TRIGGER IF EXISTS trg_route_asset ON assets;
CREATE TRIGGER trg_route_asset
  BEFORE INSERT OR UPDATE ON assets
  FOR EACH ROW
  EXECUTE FUNCTION fn_route_asset_to_category_table();


-- ============================================================
--  SECTION 5 — UPDATED_AT AUTO-REFRESH TRIGGERS
--  Keeps updated_at current on every table that has it.
-- ============================================================

CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Apply to all relevant tables
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'rigs','contracts','maintenance',
    'certificates','transfers','users',
    'reg_bop','reg_well_head','reg_well_control',
    'reg_fire_extinguishers','reg_scba'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_updated_at ON %I;
       CREATE TRIGGER trg_updated_at
         BEFORE UPDATE ON %I
         FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();',
      tbl, tbl
    );
  END LOOP;
END;
$$;


-- ============================================================
--  SECTION 6 — USEFUL VIEWS
-- ============================================================

-- ── Active assets per category ──────────────────────────────
CREATE OR REPLACE VIEW v_assets_by_category AS
SELECT
  category,
  COUNT(*)                                          AS total,
  COUNT(*) FILTER (WHERE status = 'Active')         AS active,
  COUNT(*) FILTER (WHERE status = 'Maintenance')    AS in_maintenance,
  COUNT(*) FILTER (WHERE status = 'Inactive')       AS inactive,
  ROUND(SUM(value),2)                           AS total_value_usd
FROM assets
GROUP BY category
ORDER BY category;

-- ── Assets expiring inspection within 30 days ───────────────
CREATE OR REPLACE VIEW v_expiring_inspections AS
SELECT
  a.asset_id, a.name, a.category, a.rig_name, a.location,
  a.last_inspection, a.acquisition_date,
  c.next_inspection,
  c.next_inspection - CURRENT_DATE AS days_remaining,
  inspection_status(c.next_inspection) AS status
FROM assets a
JOIN certificates c ON c.asset_id = a.asset_id
WHERE c.next_inspection <= CURRENT_DATE + INTERVAL '30 days'
ORDER BY c.next_inspection;

-- ── Full generator inventory ─────────────────────────────────
CREATE OR REPLACE VIEW v_generators_full AS
SELECT
  a.asset_id, a.name, a.serial, a.rig_name, a.location, a.status,
  a.value, g.power_kva, g.voltage_v, g.frequency_hz,
  g.fuel_type, g.engine_model, g.run_hours,
  g.last_service, g.next_service
FROM eq_generators g
JOIN assets a ON a.asset_id = g.asset_id;

-- ── Full pump inventory ──────────────────────────────────────
CREATE OR REPLACE VIEW v_pumps_full AS
SELECT
  a.asset_id, a.name, a.serial, a.rig_name, a.location, a.status,
  p.flow_rate_gpm, p.head_ft, p.power_hp,
  p.discharge_size, p.fluid_type, p.run_hours,
  p.last_service, p.next_service
FROM eq_centrifugal_pumps p
JOIN assets a ON a.asset_id = p.asset_id;


-- ============================================================
--  SECTION 7 — ROW-LEVEL SECURITY (RLS) — SUPABASE
--  Enable RLS and set permissive policies.
--  Tighten per user role as needed.
-- ============================================================

ALTER TABLE assets              ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_safety_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_generators       ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_agitators        ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_compressors      ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_engines          ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_ac_motors        ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_centrifugal_pumps ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_drilling_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_hoisting_equipment ENABLE ROW LEVEL SECURITY;
ALTER TABLE eq_winches          ENABLE ROW LEVEL SECURITY;
ALTER TABLE reg_bop             ENABLE ROW LEVEL SECURITY;
ALTER TABLE reg_well_head       ENABLE ROW LEVEL SECURITY;
ALTER TABLE reg_well_control    ENABLE ROW LEVEL SECURITY;
ALTER TABLE reg_fire_extinguishers ENABLE ROW LEVEL SECURITY;
ALTER TABLE reg_scba            ENABLE ROW LEVEL SECURITY;

-- Allow all operations for authenticated users (adjust as needed)
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'assets','eq_safety_equipment','eq_generators','eq_agitators',
    'eq_compressors','eq_engines','eq_ac_motors','eq_centrifugal_pumps',
    'eq_drilling_equipment','eq_hoisting_equipment','eq_winches',
    'reg_bop','reg_well_head','reg_well_control',
    'reg_fire_extinguishers','reg_scba'
  ] LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS allow_authenticated ON %I;
       CREATE POLICY allow_authenticated ON %I
         FOR ALL TO authenticated USING (true) WITH CHECK (true);',
      tbl, tbl
    );
  END LOOP;
END;
$$;


-- ============================================================
--  SECTION 8 — INDEXES FOR PERFORMANCE
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_eq_safety_rig      ON eq_safety_equipment(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_gen_rig          ON eq_generators(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_agit_rig         ON eq_agitators(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_comp_rig         ON eq_compressors(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_eng_rig          ON eq_engines(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_motor_rig        ON eq_ac_motors(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_pump_rig         ON eq_centrifugal_pumps(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_drill_rig        ON eq_drilling_equipment(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_hoist_rig        ON eq_hoisting_equipment(rig_name);
CREATE INDEX IF NOT EXISTS idx_eq_winch_rig        ON eq_winches(rig_name);

CREATE INDEX IF NOT EXISTS idx_reg_bop_rig         ON reg_bop(rig);
CREATE INDEX IF NOT EXISTS idx_reg_bop_expiry      ON reg_bop(expiry_inspection);
CREATE INDEX IF NOT EXISTS idx_reg_wh_rig          ON reg_well_head(rig);
CREATE INDEX IF NOT EXISTS idx_reg_wh_expiry       ON reg_well_head(expiry_inspection);
CREATE INDEX IF NOT EXISTS idx_reg_wce_rig         ON reg_well_control(rig);
CREATE INDEX IF NOT EXISTS idx_reg_wce_expiry      ON reg_well_control(expiry_inspection);
CREATE INDEX IF NOT EXISTS idx_reg_fe_rig          ON reg_fire_extinguishers(rig);
CREATE INDEX IF NOT EXISTS idx_reg_fe_expiry       ON reg_fire_extinguishers(expiry_inspection);
CREATE INDEX IF NOT EXISTS idx_reg_scba_rig        ON reg_scba(rig);
CREATE INDEX IF NOT EXISTS idx_reg_scba_expiry     ON reg_scba(expiry_inspection);


-- ============================================================
--  END OF SCHEMA
-- ============================================================


-- ============================================================
--  SECTION 9 — REQUIRED RAILWAY API ROUTES
--  Add these endpoints to your Railway backend to support
--  the register tables used by the frontend.
-- ============================================================

/*
  Add the following REST routes to your Railway/Express backend,
  following the same pattern as your existing /assets routes:

  GET    /reg-bop                  → SELECT * FROM reg_bop ORDER BY created_at DESC
  POST   /reg-bop                  → INSERT INTO reg_bop
  PUT    /reg-bop/:id              → UPDATE reg_bop WHERE id = :id
  DELETE /reg-bop/:id              → DELETE FROM reg_bop WHERE id = :id

  GET    /reg-well-head            → SELECT * FROM reg_well_head ORDER BY created_at DESC
  POST   /reg-well-head            → INSERT INTO reg_well_head
  PUT    /reg-well-head/:id        → UPDATE reg_well_head WHERE id = :id
  DELETE /reg-well-head/:id        → DELETE FROM reg_well_head WHERE id = :id

  GET    /reg-well-control         → SELECT * FROM reg_well_control ORDER BY created_at DESC
  POST   /reg-well-control         → INSERT INTO reg_well_control
  PUT    /reg-well-control/:id     → UPDATE reg_well_control WHERE id = :id
  DELETE /reg-well-control/:id     → DELETE FROM reg_well_control WHERE id = :id

  GET    /reg-fire-extinguishers   → SELECT * FROM reg_fire_extinguishers ORDER BY created_at DESC
  POST   /reg-fire-extinguishers   → INSERT INTO reg_fire_extinguishers
  PUT    /reg-fire-extinguishers/:id → UPDATE reg_fire_extinguishers WHERE id = :id
  DELETE /reg-fire-extinguishers/:id → DELETE FROM reg_fire_extinguishers WHERE id = :id

  GET    /reg-scba                 → SELECT * FROM reg_scba ORDER BY created_at DESC
  POST   /reg-scba                 → INSERT INTO reg_scba
  PUT    /reg-scba/:id             → UPDATE reg_scba WHERE id = :id
  DELETE /reg-scba/:id             → DELETE FROM reg_scba WHERE id = :id

  Each endpoint should:
  - Validate x-api-key header
  - Return { success: true, data: [...] } on GET
  - Return { success: true, data: {row} } on POST/PUT
  - Return { success: true } on DELETE
*/
