-- ============================================================
--  001_schema.sql
--  Asset Integrity & Certification Tracking System
--  Oil & Gas — Land Drilling Operations
--
--  ARCHITECTURE:
--    1. Extensions & Helpers
--    2. Reference Tables   (companies, locations, categories)
--    3. Core Tables        (assets, certificates, inspections)
--    4. Operations Tables  (transfers, maintenance, alerts)
--    5. Auth & Users       (users, roles, sessions)
--    6. Audit Log          (all changes tracked)
--    7. Triggers           (auto-status, auto-alerts, audit)
--    8. Views              (dashboard queries)
--    9. RLS Policies
--
--  Run in Supabase SQL Editor — safe to re-run (IF NOT EXISTS)
-- ============================================================

-- ────────────────────────────────────────────────────────────
--  1. EXTENSIONS
-- ────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ────────────────────────────────────────────────────────────
--  HELPER: updated_at trigger function (shared)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────
--  2. REFERENCE TABLES
-- ────────────────────────────────────────────────────────────

-- ── Companies (owners / contractors) ────────────────────────
CREATE TABLE IF NOT EXISTS companies (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          TEXT        NOT NULL UNIQUE,
  short_code    TEXT        UNIQUE,
  country       TEXT        DEFAULT 'Egypt',
  contact_name  TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  active        BOOLEAN     DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
DROP TRIGGER IF EXISTS trg_companies_updated_at ON companies;
CREATE TRIGGER trg_companies_updated_at
  BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── Location Types ──────────────────────────────────────────
-- Rigs, Yards, Repair Facilities all live in one table
-- with a type discriminator for filtering
CREATE TABLE IF NOT EXISTS locations (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  code          TEXT        NOT NULL UNIQUE,   -- e.g. RIG-01, YARD-CAIRO, REP-MAADI
  name          TEXT        NOT NULL,
  type          TEXT        NOT NULL CHECK (type IN ('Rig','Yard','Repair Facility')),
  company_id    UUID        REFERENCES companies(id) ON DELETE SET NULL,
  area          TEXT,                           -- geographic area / field
  status        TEXT        DEFAULT 'Active'
                  CHECK (status IN ('Active','Idle','Maintenance','Retired')),
  -- Rig-specific fields (NULL for Yards/Repair Facilities)
  rig_type      TEXT,                           -- Land Rig, Jack-Up, etc.
  hp            INTEGER,
  depth_rating  INTEGER,
  -- Contact
  contact_name  TEXT,
  contact_phone TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_locations_type   ON locations(type);
CREATE INDEX IF NOT EXISTS idx_locations_status ON locations(status);
DROP TRIGGER IF EXISTS trg_locations_updated_at ON locations;
CREATE TRIGGER trg_locations_updated_at
  BEFORE UPDATE ON locations FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── Equipment Categories ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id              UUID    PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT    NOT NULL UNIQUE,
  code            TEXT    NOT NULL UNIQUE,   -- e.g. BOP, DS, LIFT
  -- Default inspection intervals (days) for this category
  default_cert_validity_days  INTEGER DEFAULT 365,
  default_alert_days          INTEGER DEFAULT 90,
  -- Required inspection type for this category
  required_inspection_type    TEXT,
  active          BOOLEAN DEFAULT TRUE,
  notes           TEXT
);

-- ────────────────────────────────────────────────────────────
--  3. CORE TABLES
-- ────────────────────────────────────────────────────────────

-- ── Assets (Equipment Master) ────────────────────────────────
-- Single source of truth for every piece of equipment
CREATE TABLE IF NOT EXISTS assets (
  id                  UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id            TEXT        NOT NULL UNIQUE,   -- AST-00001 (auto-generated)
  name                TEXT        NOT NULL,
  category_id         UUID        REFERENCES categories(id) ON DELETE RESTRICT,
  category_name       TEXT,                          -- denormalized for speed
  manufacturer        TEXT,
  model               TEXT,
  serial_number       TEXT,                          -- from supplier / nameplate
  part_number         TEXT,
  -- Location (always know where this asset is)
  location_id         UUID        REFERENCES locations(id) ON DELETE SET NULL,
  location_code       TEXT,                          -- denormalized
  location_name       TEXT,                          -- denormalized
  -- Status lifecycle
  status              TEXT        DEFAULT 'Active'
                        CHECK (status IN (
                          'Active',         -- in operation
                          'In Inspection',  -- pulled for inspection
                          'In Repair',      -- at repair facility
                          'Standby',        -- available but not deployed
                          'In Transit',     -- being transferred
                          'Retired',        -- decommissioned
                          'Scrapped'        -- destroyed/disposed
                        )),
  -- Certificate summary (live snapshot, updated by trigger)
  cert_status         TEXT        DEFAULT 'No Certificate'
                        CHECK (cert_status IN (
                          'Valid',
                          'Expiring Soon',  -- within alert_days
                          'Expired',
                          'No Certificate'
                        )),
  cert_expiry_date    DATE,                          -- nearest upcoming expiry
  -- Acquisition
  company_id          UUID        REFERENCES companies(id) ON DELETE SET NULL,
  acquisition_date    DATE,
  po_number           TEXT,                          -- purchase order ref
  -- Traceability
  supplier_name       TEXT,
  country_of_origin   TEXT,
  -- Misc
  notes               TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_assets_status      ON assets(status);
CREATE INDEX IF NOT EXISTS idx_assets_category_id ON assets(category_id);
CREATE INDEX IF NOT EXISTS idx_assets_location_id ON assets(location_id);
CREATE INDEX IF NOT EXISTS idx_assets_cert_status ON assets(cert_status);
CREATE INDEX IF NOT EXISTS idx_assets_cert_expiry ON assets(cert_expiry_date);
DROP TRIGGER IF EXISTS trg_assets_updated_at ON assets;
CREATE TRIGGER trg_assets_updated_at
  BEFORE UPDATE ON assets FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── Certificates ─────────────────────────────────────────────
-- Each certificate is linked to one asset.
-- An asset can have multiple certificates (different types).
CREATE TABLE IF NOT EXISTS certificates (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  cert_id           TEXT        NOT NULL UNIQUE,     -- CERT-00001
  asset_id          UUID        NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  asset_asset_id    TEXT,                            -- denormalized for display
  asset_name        TEXT,                            -- denormalized for display
  -- Certificate details
  inspection_type   TEXT        NOT NULL
                      CHECK (inspection_type IN (
                        'Cat IV','Annual Inspection','6-Month Inspection',
                        'Quarterly Inspection','Monthly Inspection',
                        'Weekly Inspection','Bi-Weekly Inspection',
                        'Load Test','BOP Pressure Test','Calibration',
                        'Pressure Test','UT NDT Inspection'
                      )),
  issued_by         TEXT,                            -- certifying body / company
  issue_date        DATE        NOT NULL,
  expiry_date       DATE        NOT NULL,
  -- Validity
  validity_days     INTEGER     GENERATED ALWAYS AS
                      (expiry_date - issue_date) STORED,
  -- Days until expiry (computed in views/queries)
  -- Certificate document
  cert_link         TEXT,                            -- external URL to certificate
  cert_number       TEXT,                            -- certificate reference number
  -- Alert config
  alert_days        INTEGER     DEFAULT 90,          -- alert this many days before expiry
  alert_sent        BOOLEAN     DEFAULT FALSE,       -- has 90-day alert been sent?
  alert_sent_at     TIMESTAMPTZ,
  -- Next inspection
  next_inspection_date DATE,
  -- Status (computed by trigger on insert/update)
  status            TEXT        DEFAULT 'Valid'
                      CHECK (status IN ('Valid','Expiring Soon','Expired','Superseded')),
  -- Superseded by newer certificate
  superseded_by     UUID        REFERENCES certificates(id) ON DELETE SET NULL,
  is_current        BOOLEAN     DEFAULT TRUE,        -- false when superseded
  -- Meta
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_certs_asset_id    ON certificates(asset_id);
CREATE INDEX IF NOT EXISTS idx_certs_expiry      ON certificates(expiry_date);
CREATE INDEX IF NOT EXISTS idx_certs_status      ON certificates(status);
CREATE INDEX IF NOT EXISTS idx_certs_is_current  ON certificates(is_current);
DROP TRIGGER IF EXISTS trg_certs_updated_at ON certificates;
CREATE TRIGGER trg_certs_updated_at
  BEFORE UPDATE ON certificates FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ────────────────────────────────────────────────────────────
--  4. OPERATIONS TABLES
-- ────────────────────────────────────────────────────────────

-- ── Inspections ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS inspections (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  inspection_id     TEXT        NOT NULL UNIQUE,     -- INSP-00001
  asset_id          UUID        NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  asset_name        TEXT,
  -- Scheduling
  scheduled_date    DATE        NOT NULL,
  performed_date    DATE,
  -- Details
  inspection_type   TEXT        NOT NULL
                      CHECK (inspection_type IN (
                        'Cat IV','Annual Inspection','6-Month Inspection',
                        'Quarterly Inspection','Monthly Inspection',
                        'Weekly Inspection','Bi-Weekly Inspection',
                        'Load Test','BOP Pressure Test','Calibration',
                        'Pressure Test','UT NDT Inspection'
                      )),
  inspector_name    TEXT,
  inspector_company TEXT,
  location_id       UUID        REFERENCES locations(id) ON DELETE SET NULL,
  location_name     TEXT,
  -- Result
  result            TEXT        CHECK (result IN ('Pass','Fail','Conditional Pass','Pending')),
  findings          TEXT,
  recommendations   TEXT,
  -- Certificate generated from this inspection
  certificate_id    UUID        REFERENCES certificates(id) ON DELETE SET NULL,
  -- Cost
  cost_per_day      NUMERIC(12,2) DEFAULT 0,
  total_cost        NUMERIC(14,2) DEFAULT 0,
  po_number         TEXT,
  service_order     TEXT,
  -- Status
  status            TEXT        DEFAULT 'Scheduled'
                      CHECK (status IN ('Scheduled','In Progress','Completed','Cancelled','Overdue')),
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_insp_asset_id  ON inspections(asset_id);
CREATE INDEX IF NOT EXISTS idx_insp_scheduled ON inspections(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_insp_status    ON inspections(status);
DROP TRIGGER IF EXISTS trg_insp_updated_at ON inspections;
CREATE TRIGGER trg_insp_updated_at
  BEFORE UPDATE ON inspections FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── Equipment Transfers ───────────────────────────────────────
-- Full transfer workflow: Pending → Approved → In Transit → Completed
CREATE TABLE IF NOT EXISTS transfers (
  id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  transfer_id       TEXT        NOT NULL UNIQUE,     -- TRF-00001
  asset_id          UUID        NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  asset_name        TEXT,
  asset_asset_id    TEXT,
  -- Route
  from_location_id  UUID        REFERENCES locations(id) ON DELETE SET NULL,
  from_location     TEXT,
  to_location_id    UUID        REFERENCES locations(id) ON DELETE SET NULL,
  to_location       TEXT,
  -- Transfer type
  transfer_type     TEXT        DEFAULT 'Rig to Rig'
                      CHECK (transfer_type IN (
                        'Rig to Rig','Rig to Yard','Yard to Rig',
                        'Rig to Repair','Repair to Rig','Repair to Yard',
                        'Yard to Repair','Yard to Yard'
                      )),
  -- Workflow
  status            TEXT        DEFAULT 'Pending'
                      CHECK (status IN ('Pending','Approved','In Transit','Completed','Cancelled','Rejected')),
  requested_by      TEXT,
  requested_at      TIMESTAMPTZ DEFAULT NOW(),
  approved_by       TEXT,
  approved_at       TIMESTAMPTZ,
  dispatched_at     TIMESTAMPTZ,
  received_at       TIMESTAMPTZ,
  required_date     DATE,
  -- Reason & notes
  reason            TEXT,
  transport_method  TEXT,       -- Truck, Helicopter, etc.
  manifest_number   TEXT,
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_transfers_asset_id ON transfers(asset_id);
CREATE INDEX IF NOT EXISTS idx_transfers_status   ON transfers(status);
DROP TRIGGER IF EXISTS trg_transfers_updated_at ON transfers;
CREATE TRIGGER trg_transfers_updated_at
  BEFORE UPDATE ON transfers FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── Alert Log ─────────────────────────────────────────────────
-- Every system alert is recorded here for audit
CREATE TABLE IF NOT EXISTS alert_log (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  alert_type    TEXT        NOT NULL
                  CHECK (alert_type IN (
                    'Cert Expiring 90 Days',
                    'Cert Expiring 30 Days',
                    'Cert Expired',
                    'Inspection Due',
                    'Inspection Overdue',
                    'Transfer Approved',
                    'Transfer Completed'
                  )),
  asset_id      UUID        REFERENCES assets(id) ON DELETE CASCADE,
  asset_name    TEXT,
  cert_id       UUID        REFERENCES certificates(id) ON DELETE CASCADE,
  expiry_date   DATE,
  days_remaining INTEGER,
  sent_to       TEXT[],     -- array of email addresses
  sent_at       TIMESTAMPTZ DEFAULT NOW(),
  channel       TEXT        DEFAULT 'Email'
                  CHECK (channel IN ('Email','Dashboard','Both')),
  acknowledged  BOOLEAN     DEFAULT FALSE,
  ack_by        TEXT,
  ack_at        TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_alerts_asset_id ON alert_log(asset_id);
CREATE INDEX IF NOT EXISTS idx_alerts_type     ON alert_log(alert_type);
CREATE INDEX IF NOT EXISTS idx_alerts_sent_at  ON alert_log(sent_at DESC);

-- ── Maintenance Orders ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS maintenance_orders (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id        TEXT        NOT NULL UNIQUE,       -- MO-00001
  asset_id        UUID        NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
  asset_name      TEXT,
  -- Trigger
  triggered_by    TEXT        CHECK (triggered_by IN (
                    'Scheduled','Certificate Expiry','Inspection Fail',
                    'Transfer','Manual','Breakdown'
                  )),
  triggered_from  UUID,       -- cert_id or inspection_id that triggered this
  -- Work details
  work_type       TEXT        CHECK (work_type IN (
                    'Preventive','Corrective','Predictive','Emergency'
                  )),
  description     TEXT        NOT NULL,
  priority        TEXT        DEFAULT 'Normal'
                    CHECK (priority IN ('Low','Normal','High','Critical')),
  assigned_to     TEXT,
  location_id     UUID        REFERENCES locations(id) ON DELETE SET NULL,
  -- Schedule
  planned_date    DATE,
  actual_start    TIMESTAMPTZ,
  actual_end      TIMESTAMPTZ,
  -- Status
  status          TEXT        DEFAULT 'Open'
                    CHECK (status IN ('Open','In Progress','On Hold','Completed','Cancelled')),
  -- Cost
  labour_cost     NUMERIC(12,2) DEFAULT 0,
  parts_cost      NUMERIC(12,2) DEFAULT 0,
  total_cost      NUMERIC(14,2) GENERATED ALWAYS AS (labour_cost + parts_cost) STORED,
  -- Result
  completion_notes TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_mo_asset_id ON maintenance_orders(asset_id);
CREATE INDEX IF NOT EXISTS idx_mo_status   ON maintenance_orders(status);
DROP TRIGGER IF EXISTS trg_mo_updated_at ON maintenance_orders;
CREATE TRIGGER trg_mo_updated_at
  BEFORE UPDATE ON maintenance_orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ────────────────────────────────────────────────────────────
--  5. AUTH & USERS
-- ────────────────────────────────────────────────────────────

-- ── User Profiles (linked to Supabase Auth) ──────────────────
-- auth.users is managed by Supabase; this extends it
CREATE TABLE IF NOT EXISTS user_profiles (
  id          UUID        PRIMARY KEY,  -- matches auth.users.id
  email       TEXT        NOT NULL UNIQUE,
  full_name   TEXT        NOT NULL,
  role        TEXT        NOT NULL DEFAULT 'Viewer'
                CHECK (role IN (
                  'Admin',           -- full access
                  'Asset Controller',-- manage transfers, edit assets
                  'Engineer',        -- upload inspections & certs
                  'Maintenance',     -- perform inspections, update status
                  'Manager',         -- view-only + reports
                  'Viewer'           -- read-only
                )),
  department  TEXT,
  phone       TEXT,
  location_id UUID        REFERENCES locations(id) ON DELETE SET NULL,
  active      BOOLEAN     DEFAULT TRUE,
  last_login  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
DROP TRIGGER IF EXISTS trg_up_updated_at ON user_profiles;
CREATE TRIGGER trg_up_updated_at
  BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ────────────────────────────────────────────────────────────
--  6. AUDIT LOG
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
  id          BIGSERIAL   PRIMARY KEY,
  table_name  TEXT        NOT NULL,
  record_id   UUID,
  action      TEXT        NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
  old_data    JSONB,
  new_data    JSONB,
  changed_by  UUID,       -- user_profiles.id
  changed_by_email TEXT,
  changed_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_table     ON audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_record    ON audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_changed_at ON audit_log(changed_at DESC);

-- Generic audit trigger function
CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_data, new_data)
  VALUES (
    TG_TABLE_NAME,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
    TG_OP,
    CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END
  );
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attach audit to core tables
DROP TRIGGER IF EXISTS trg_audit_assets       ON assets;
CREATE TRIGGER trg_audit_assets       AFTER INSERT OR UPDATE OR DELETE ON assets
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_certificates ON certificates;
CREATE TRIGGER trg_audit_certificates AFTER INSERT OR UPDATE OR DELETE ON certificates
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

DROP TRIGGER IF EXISTS trg_audit_transfers    ON transfers;
CREATE TRIGGER trg_audit_transfers    AFTER INSERT OR UPDATE OR DELETE ON transfers
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- ────────────────────────────────────────────────────────────
--  7. BUSINESS LOGIC TRIGGERS
-- ────────────────────────────────────────────────────────────

-- ── RULE 1: Certificate status auto-update ───────────────────
-- When a certificate is inserted or updated, compute its status
-- based on today's date and alert_days threshold.
-- Also updates the parent asset's cert_status snapshot.
CREATE OR REPLACE FUNCTION fn_cert_status_update()
RETURNS TRIGGER AS $$
DECLARE
  v_days_remaining INTEGER;
BEGIN
  v_days_remaining := NEW.expiry_date - CURRENT_DATE;

  IF v_days_remaining < 0 THEN
    NEW.status := 'Expired';
  ELSIF v_days_remaining <= NEW.alert_days THEN
    NEW.status := 'Expiring Soon';
  ELSE
    NEW.status := 'Valid';
  END IF;

  -- Sync asset cert_status snapshot for the nearest expiry
  UPDATE assets
  SET
    cert_status      = NEW.status,
    cert_expiry_date = NEW.expiry_date
  WHERE id = NEW.asset_id
    AND (cert_expiry_date IS NULL OR NEW.expiry_date <= cert_expiry_date);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cert_status ON certificates;
CREATE TRIGGER trg_cert_status
  BEFORE INSERT OR UPDATE ON certificates
  FOR EACH ROW EXECUTE FUNCTION fn_cert_status_update();

-- ── RULE 2: Inspection completion → update asset + next date ─
-- When an inspection is marked Completed:
--  a) Update asset status back to Active
--  b) Calculate next inspection date
--  c) Create/link certificate if cert data present
CREATE OR REPLACE FUNCTION fn_inspection_completed()
RETURNS TRIGGER AS $$
DECLARE
  v_interval INTEGER;
BEGIN
  -- Only fire when status changes TO Completed
  IF NEW.status = 'Completed' AND (OLD.status IS DISTINCT FROM 'Completed') THEN

    -- Calculate next inspection date based on type
    v_interval := CASE NEW.inspection_type
      WHEN 'Annual Inspection'     THEN 365
      WHEN '6-Month Inspection'    THEN 180
      WHEN 'Quarterly Inspection'  THEN 90
      WHEN 'Monthly Inspection'    THEN 30
      WHEN 'Weekly Inspection'     THEN 7
      WHEN 'Bi-Weekly Inspection'  THEN 14
      WHEN 'Cat IV'                THEN 1460  -- 4 years
      WHEN 'Load Test'             THEN 365
      WHEN 'BOP Pressure Test'     THEN 90
      WHEN 'Calibration'           THEN 365
      WHEN 'Pressure Test'         THEN 180
      WHEN 'UT NDT Inspection'     THEN 365
      ELSE 365
    END;

    NEW.next_inspection_date := COALESCE(NEW.performed_date, CURRENT_DATE) + v_interval;

    -- Update asset status to Active (released from inspection)
    UPDATE assets
    SET status = 'Active'
    WHERE id = NEW.asset_id AND status = 'In Inspection';

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inspection_completed ON inspections;
CREATE TRIGGER trg_inspection_completed
  BEFORE UPDATE ON inspections
  FOR EACH ROW EXECUTE FUNCTION fn_inspection_completed();

-- ── RULE 3: Transfer approval → update asset location ────────
-- When a transfer status changes to Completed:
--  a) Update asset location_id, location_code, location_name
--  b) Update asset status back to Active (or Standby)
CREATE OR REPLACE FUNCTION fn_transfer_completed()
RETURNS TRIGGER AS $$
DECLARE
  v_loc locations%ROWTYPE;
BEGIN
  IF NEW.status = 'In Transit' AND OLD.status = 'Approved' THEN
    -- Asset is now in transit
    UPDATE assets SET status = 'In Transit'
    WHERE id = NEW.asset_id;
  END IF;

  IF NEW.status = 'Completed' AND OLD.status = 'In Transit' THEN
    -- Fetch destination location details
    SELECT * INTO v_loc FROM locations WHERE id = NEW.to_location_id;

    -- Update asset location
    UPDATE assets
    SET
      location_id   = NEW.to_location_id,
      location_code = v_loc.code,
      location_name = v_loc.name,
      status        = 'Active'
    WHERE id = NEW.asset_id;

    NEW.received_at := NOW();
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_transfer_completed ON transfers;
CREATE TRIGGER trg_transfer_completed
  BEFORE UPDATE ON transfers
  FOR EACH ROW EXECUTE FUNCTION fn_transfer_completed();

-- ── AUTO: Asset ID generation ─────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS asset_id_seq START 1;

CREATE OR REPLACE FUNCTION fn_generate_asset_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.asset_id IS NULL OR NEW.asset_id = '' THEN
    NEW.asset_id := 'AST-' || LPAD(nextval('asset_id_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_asset_id ON assets;
CREATE TRIGGER trg_asset_id
  BEFORE INSERT ON assets
  FOR EACH ROW EXECUTE FUNCTION fn_generate_asset_id();

-- ── AUTO: Certificate ID generation ──────────────────────────
CREATE SEQUENCE IF NOT EXISTS cert_id_seq START 1;

CREATE OR REPLACE FUNCTION fn_generate_cert_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.cert_id IS NULL OR NEW.cert_id = '' THEN
    NEW.cert_id := 'CERT-' || LPAD(nextval('cert_id_seq')::TEXT, 5, '0');
  END IF;
  -- Denormalize asset info
  SELECT asset_id, name INTO NEW.asset_asset_id, NEW.asset_name
  FROM assets WHERE id = NEW.asset_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cert_id ON certificates;
CREATE TRIGGER trg_cert_id
  BEFORE INSERT ON certificates
  FOR EACH ROW EXECUTE FUNCTION fn_generate_cert_id();

-- ── AUTO: Inspection ID generation ───────────────────────────
CREATE SEQUENCE IF NOT EXISTS insp_id_seq START 1;

CREATE OR REPLACE FUNCTION fn_generate_insp_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.inspection_id IS NULL OR NEW.inspection_id = '' THEN
    NEW.inspection_id := 'INSP-' || LPAD(nextval('insp_id_seq')::TEXT, 5, '0');
  END IF;
  SELECT name INTO NEW.asset_name FROM assets WHERE id = NEW.asset_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_insp_id ON inspections;
CREATE TRIGGER trg_insp_id
  BEFORE INSERT ON inspections
  FOR EACH ROW EXECUTE FUNCTION fn_generate_insp_id();

-- ── AUTO: Transfer ID generation ─────────────────────────────
CREATE SEQUENCE IF NOT EXISTS trf_id_seq START 1;

CREATE OR REPLACE FUNCTION fn_generate_trf_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.transfer_id IS NULL OR NEW.transfer_id = '' THEN
    NEW.transfer_id := 'TRF-' || LPAD(nextval('trf_id_seq')::TEXT, 5, '0');
  END IF;
  SELECT name, asset_id INTO NEW.asset_name, NEW.asset_asset_id
  FROM assets WHERE id = NEW.asset_id;
  -- Capture current location as from_location
  IF NEW.from_location IS NULL THEN
    SELECT location_name INTO NEW.from_location FROM assets WHERE id = NEW.asset_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_trf_id ON transfers;
CREATE TRIGGER trg_trf_id
  BEFORE INSERT ON transfers
  FOR EACH ROW EXECUTE FUNCTION fn_generate_trf_id();

-- ── AUTO: Maintenance Order ID generation ────────────────────
CREATE SEQUENCE IF NOT EXISTS mo_id_seq START 1;

CREATE OR REPLACE FUNCTION fn_generate_mo_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_id IS NULL OR NEW.order_id = '' THEN
    NEW.order_id := 'MO-' || LPAD(nextval('mo_id_seq')::TEXT, 5, '0');
  END IF;
  SELECT name INTO NEW.asset_name FROM assets WHERE id = NEW.asset_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_mo_id ON maintenance_orders;
CREATE TRIGGER trg_mo_id
  BEFORE INSERT ON maintenance_orders
  FOR EACH ROW EXECUTE FUNCTION fn_generate_mo_id();

-- ────────────────────────────────────────────────────────────
--  8. VIEWS (pre-built queries for dashboard)
-- ────────────────────────────────────────────────────────────

-- ── Dashboard KPI view ────────────────────────────────────────
CREATE OR REPLACE VIEW vw_dashboard_kpis AS
SELECT
  (SELECT COUNT(*) FROM assets WHERE status NOT IN ('Retired','Scrapped'))            AS total_active_assets,
  (SELECT COUNT(*) FROM assets WHERE cert_status = 'Expired')                         AS expired_certs,
  (SELECT COUNT(*) FROM assets WHERE cert_status = 'Expiring Soon')                   AS expiring_soon_certs,
  (SELECT COUNT(*) FROM assets WHERE cert_status = 'Valid')                           AS valid_certs,
  (SELECT COUNT(*) FROM assets WHERE cert_status = 'No Certificate')                  AS no_cert_assets,
  (SELECT COUNT(*) FROM inspections WHERE status = 'Overdue')                         AS overdue_inspections,
  (SELECT COUNT(*) FROM inspections WHERE status = 'Scheduled'
     AND scheduled_date BETWEEN CURRENT_DATE AND CURRENT_DATE + 30)                   AS upcoming_inspections_30d,
  (SELECT COUNT(*) FROM transfers WHERE status IN ('Pending','Approved','In Transit')) AS active_transfers;

-- ── Equipment list with cert status ──────────────────────────
CREATE OR REPLACE VIEW vw_equipment_status AS
SELECT
  a.id,
  a.asset_id,
  a.name,
  a.category_name,
  a.manufacturer,
  a.serial_number,
  a.status        AS asset_status,
  a.cert_status,
  a.cert_expiry_date,
  (a.cert_expiry_date - CURRENT_DATE) AS days_to_expiry,
  a.location_code,
  a.location_name,
  l.type          AS location_type,
  c.name          AS company_name
FROM assets a
LEFT JOIN locations l ON a.location_id = l.id
LEFT JOIN companies c ON a.company_id  = c.id
WHERE a.status NOT IN ('Retired','Scrapped')
ORDER BY a.cert_expiry_date ASC NULLS LAST;

-- ── Certificate expiry report ─────────────────────────────────
CREATE OR REPLACE VIEW vw_cert_expiry_report AS
SELECT
  ce.id              AS cert_id_pk,
  ce.cert_id,
  ce.inspection_type,
  ce.issue_date,
  ce.expiry_date,
  (ce.expiry_date - CURRENT_DATE) AS days_remaining,
  ce.status          AS cert_status,
  ce.cert_link,
  ce.cert_number,
  ce.issued_by,
  ce.alert_days,
  ce.alert_sent,
  a.asset_id,
  a.name             AS asset_name,
  a.category_name,
  a.serial_number,
  a.location_name,
  l.type             AS location_type
FROM certificates ce
JOIN assets a ON ce.asset_id = a.id
LEFT JOIN locations l ON a.location_id = l.id
WHERE ce.is_current = TRUE
ORDER BY ce.expiry_date ASC;

-- ── Equipment by rig ──────────────────────────────────────────
CREATE OR REPLACE VIEW vw_equipment_by_location AS
SELECT
  l.code             AS location_code,
  l.name             AS location_name,
  l.type             AS location_type,
  COUNT(a.id)        AS total_equipment,
  COUNT(CASE WHEN a.cert_status = 'Valid'         THEN 1 END) AS certs_valid,
  COUNT(CASE WHEN a.cert_status = 'Expiring Soon' THEN 1 END) AS certs_expiring,
  COUNT(CASE WHEN a.cert_status = 'Expired'       THEN 1 END) AS certs_expired,
  COUNT(CASE WHEN a.cert_status = 'No Certificate'THEN 1 END) AS no_cert
FROM locations l
LEFT JOIN assets a ON a.location_id = l.id
  AND a.status NOT IN ('Retired','Scrapped')
GROUP BY l.id, l.code, l.name, l.type
ORDER BY l.type, l.name;

-- ── Inspection due list ───────────────────────────────────────
CREATE OR REPLACE VIEW vw_inspection_due AS
SELECT
  i.inspection_id,
  i.scheduled_date,
  (i.scheduled_date - CURRENT_DATE) AS days_until_due,
  i.inspection_type,
  i.status,
  a.asset_id,
  a.name             AS asset_name,
  a.category_name,
  a.serial_number,
  a.location_name,
  i.inspector_name,
  i.cost_per_day
FROM inspections i
JOIN assets a ON i.asset_id = a.id
WHERE i.status IN ('Scheduled','Overdue')
ORDER BY i.scheduled_date ASC;

-- ── Transfer history ──────────────────────────────────────────
CREATE OR REPLACE VIEW vw_transfer_history AS
SELECT
  t.transfer_id,
  t.transfer_type,
  t.status,
  t.from_location,
  t.to_location,
  t.requested_by,
  t.requested_at::DATE AS request_date,
  t.approved_by,
  t.approved_at::DATE  AS approval_date,
  t.received_at::DATE  AS completion_date,
  a.asset_id,
  a.name               AS asset_name,
  a.category_name,
  a.serial_number
FROM transfers t
JOIN assets a ON t.asset_id = a.id
ORDER BY t.requested_at DESC;

-- ────────────────────────────────────────────────────────────
--  9. ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────

ALTER TABLE companies           ENABLE ROW LEVEL SECURITY;
ALTER TABLE locations           ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories          ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets              ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificates        ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections         ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers           ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_log           ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_orders  ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log           ENABLE ROW LEVEL SECURITY;

-- Service role (Worker) bypasses RLS — open policy for API use
-- In production replace with JWT-based policies per role
DROP POLICY IF EXISTS "allow_all_companies"          ON companies;
DROP POLICY IF EXISTS "allow_all_locations"          ON locations;
DROP POLICY IF EXISTS "allow_all_categories"         ON categories;
DROP POLICY IF EXISTS "allow_all_assets"             ON assets;
DROP POLICY IF EXISTS "allow_all_certificates"       ON certificates;
DROP POLICY IF EXISTS "allow_all_inspections"        ON inspections;
DROP POLICY IF EXISTS "allow_all_transfers"          ON transfers;
DROP POLICY IF EXISTS "allow_all_alert_log"          ON alert_log;
DROP POLICY IF EXISTS "allow_all_maintenance_orders" ON maintenance_orders;
DROP POLICY IF EXISTS "allow_all_user_profiles"      ON user_profiles;
DROP POLICY IF EXISTS "allow_all_audit_log"          ON audit_log;

CREATE POLICY "allow_all_companies"          ON companies          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_locations"          ON locations          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_categories"         ON categories         FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_assets"             ON assets             FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_certificates"       ON certificates       FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_inspections"        ON inspections        FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_transfers"          ON transfers          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_alert_log"          ON alert_log          FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_maintenance_orders" ON maintenance_orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_user_profiles"      ON user_profiles      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "allow_all_audit_log"          ON audit_log          FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
--  END OF 001_schema.sql
--  Next file: 002_seed.sql (reference data)
-- ============================================================
