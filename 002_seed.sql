-- ============================================================
--  002_seed.sql
--  Reference Data — Oil & Gas Land Drilling Operations
--
--  ORDER:
--    1. Companies
--    2. Locations  (Rigs, Yards, Repair Facilities)
--    3. Categories (Equipment Types)
--
--  Safe to re-run — uses INSERT ... ON CONFLICT DO NOTHING
-- ============================================================


-- ────────────────────────────────────────────────────────────
--  1. COMPANIES
-- ────────────────────────────────────────────────────────────
INSERT INTO companies (name, short_code, country, contact_email, active)
VALUES
  ('National Drilling Company',       'NDC',   'Egypt', 'ops@ndc.com.eg',       TRUE),
  ('Egyptian Drilling Company',       'EDC',   'Egypt', 'ops@edc.com.eg',       TRUE),
  ('Weatherford International',       'WFT',   'Egypt', 'egypt@weatherford.com', TRUE),
  ('Schlumberger / SLB',              'SLB',   'Egypt', 'egypt@slb.com',        TRUE),
  ('Halliburton',                     'HAL',   'Egypt', 'egypt@halliburton.com', TRUE),
  ('Baker Hughes',                    'BKR',   'Egypt', 'egypt@bakerhughes.com', TRUE),
  ('ENPPI',                           'ENPPI', 'Egypt', 'info@enppi.com',        TRUE),
  ('General Petroleum Company',       'GPC',   'Egypt', 'info@gpc.com.eg',       TRUE),
  ('Petrobel',                        'PBL',   'Egypt', 'info@petrobel.com',     TRUE),
  ('Third Party Inspection Body',     'TPIB',  'Egypt', 'certs@tpib.com',        TRUE)
ON CONFLICT (name) DO NOTHING;


-- ────────────────────────────────────────────────────────────
--  2. LOCATIONS
-- ────────────────────────────────────────────────────────────

-- ── Land Rigs ───────────────────────────────────────────────
INSERT INTO locations (code, name, type, area, status, rig_type, hp, depth_rating, notes)
VALUES
  ('RIG-01',  'Rig 1  — Western Desert',  'Rig', 'Western Desert', 'Active',      'Land Rig', 2000, 20000, 'Currently drilling'),
  ('RIG-02',  'Rig 2  — Sinai',           'Rig', 'Sinai',          'Active',      'Land Rig', 1500, 15000, 'Currently drilling'),
  ('RIG-03',  'Rig 3  — Gulf of Suez',    'Rig', 'Gulf of Suez',   'Active',      'Land Rig', 3000, 25000, 'Currently drilling'),
  ('RIG-04',  'Rig 4  — Delta',           'Rig', 'Nile Delta',     'Idle',        'Land Rig', 2000, 18000, 'Awaiting contract'),
  ('RIG-05',  'Rig 5  — Western Desert',  'Rig', 'Western Desert', 'Active',      'Land Rig', 2500, 22000, 'Currently drilling'),
  ('RIG-06',  'Rig 6  — Eastern Desert',  'Rig', 'Eastern Desert', 'Maintenance', 'Land Rig', 1500, 15000, 'Under maintenance'),
  ('RIG-07',  'Rig 7  — Sinai',           'Rig', 'Sinai',          'Active',      'Land Rig', 2000, 20000, 'Currently drilling'),
  ('RIG-08',  'Rig 8  — Gulf of Suez',    'Rig', 'Gulf of Suez',   'Active',      'Land Rig', 3000, 30000, 'Currently drilling'),
  ('RIG-09',  'Rig 9  — Delta',           'Rig', 'Nile Delta',     'Idle',        'Land Rig', 1000, 10000, 'Stacked'),
  ('RIG-10',  'Rig 10 — Western Desert',  'Rig', 'Western Desert', 'Active',      'Land Rig', 2000, 20000, 'Currently drilling')
ON CONFLICT (code) DO NOTHING;

-- ── Yards (Storage / Laydown Areas) ─────────────────────────
INSERT INTO locations (code, name, type, area, status, notes)
VALUES
  ('YARD-CAI', 'Cairo Laydown Yard',        'Yard', 'Cairo',          'Active', 'Main storage yard'),
  ('YARD-ALX', 'Alexandria Equipment Yard', 'Yard', 'Alexandria',     'Active', 'North coast storage'),
  ('YARD-HRG', 'Hurghada Yard',             'Yard', 'Gulf of Suez',   'Active', 'Eastern yard'),
  ('YARD-WD',  'Western Desert Yard',       'Yard', 'Western Desert', 'Active', 'Field support yard'),
  ('YARD-SNI', 'Sinai Field Yard',          'Yard', 'Sinai',          'Active', 'Sinai operations yard')
ON CONFLICT (code) DO NOTHING;

-- ── Repair Facilities ────────────────────────────────────────
INSERT INTO locations (code, name, type, area, status, notes)
VALUES
  ('REP-CAI',  'Cairo Repair Workshop',       'Repair Facility', 'Cairo',        'Active', 'Main repair facility — BOP & well control'),
  ('REP-ALX',  'Alexandria Service Center',   'Repair Facility', 'Alexandria',   'Active', 'Lifting & pressure equipment'),
  ('REP-WFT',  'Weatherford Service Base',    'Repair Facility', 'Cairo',        'Active', 'OEM authorized repair'),
  ('REP-SLB',  'SLB Workshop',                'Repair Facility', 'Cairo',        'Active', 'Measurement & instrumentation'),
  ('REP-EXT',  'External Certification Lab',  'Repair Facility', 'Cairo',        'Active', 'NDT, Load test, Calibration')
ON CONFLICT (code) DO NOTHING;


-- ────────────────────────────────────────────────────────────
--  3. EQUIPMENT CATEGORIES
--  default_cert_validity_days = standard recertification interval
--  default_alert_days         = alert before expiry
-- ────────────────────────────────────────────────────────────
INSERT INTO categories
  (name, code, default_cert_validity_days, default_alert_days, required_inspection_type, notes)
VALUES
  -- Well Control (highest criticality — shortest intervals)
  ('BOP Equipment',            'BOP',   365, 90,  'BOP Pressure Test',    'Blowout preventer stack, rams, annulars'),
  ('BOP Control System',       'BOPCS', 365, 90,  'BOP Pressure Test',    'Hydraulic control unit, accumulators'),
  ('Choke & Kill Manifold',    'CKM',   180, 60,  'Pressure Test',        'High-pressure flow control'),
  ('Well Control Valves',      'WCV',   180, 60,  'Pressure Test',        'Gate valves, check valves, Kelly cocks'),

  -- Rotary & Drill String
  ('Drill String',             'DS',    365, 90,  'UT NDT Inspection',    'Drill pipe, HWDP, drill collars'),
  ('Top Drive System',         'TDS',   365, 90,  'Annual Inspection',    'Motor, gearbox, swivel, dolly'),
  ('Rotary Table & Kelly',     'RTK',   365, 90,  'Annual Inspection',    'Rotary table, kelly bushing, drive'),

  -- Lifting & Rigging (LOLER compliance)
  ('Lifting Equipment',        'LIFT',  365, 90,  'Load Test',            'Cranes, air hoists, chain blocks'),
  ('Rigging Equipment',        'RIG',   365, 90,  'Load Test',            'Slings, shackles, hooks, swivels'),
  ('Travelling Block & Hook',  'TBH',   365, 90,  'Load Test',            'Crown block, travelling block, hook'),

  -- Wellhead
  ('Wellhead Equipment',       'WHE',   365, 90,  'Pressure Test',        'Casing heads, tubing heads, X-trees'),
  ('Casing Running Tools',     'CRT',   365, 90,  'Annual Inspection',    'Slips, elevators, spiders, power tongs'),

  -- Pressure Equipment
  ('Pressure Vessels',         'PV',    365, 90,  'Pressure Test',        'Mud gas separator, trip tank, pits'),
  ('High Pressure Hoses',      'HPH',   180, 60,  'Pressure Test',        'Standpipe, rotary, kelly hose'),
  ('Mud Pumps',                'MP',    365, 90,  'Annual Inspection',    'Duplex/triplex pumps, liners, pistons'),

  -- Safety & Detection
  ('Safety Valves',            'SV',    365, 90,  'Pressure Test',        'IBOP, float valves, safety subs'),
  ('Fire & Gas Detection',     'FGD',   365, 90,  'Calibration',          'Gas detectors, H2S monitors, smoke'),
  ('Fire Suppression',         'FS',    365, 90,  'Annual Inspection',    'Fire extinguishers, deluge, foam systems'),
  ('SCBA & Breathing Gear',    'SCBA',  365, 90,  'Annual Inspection',    'Self-contained breathing apparatus'),

  -- Electrical & Instrumentation
  ('Electrical Equipment',     'ELEC',  365, 90,  'Annual Inspection',    'MCC, VFD, transformers, cables'),
  ('Instrumentation',          'INST',  365, 90,  'Calibration',          'Pressure gauges, sensors, recorders'),
  ('Drawworks & Controls',     'DW',    365, 90,  'Annual Inspection',    'Drum, brakes, catheads, control console'),

  -- Cranes & Heavy Lift
  ('Cranes',                   'CRN',   365, 90,  'Load Test',            'Pedestal, knuckle-boom, mobile cranes'),

  -- Cementing & Stimulation
  ('Cementing Equipment',      'CEM',   365, 90,  'Pressure Test',        'Cement unit, head, float equipment'),
  ('Coiled Tubing Unit',       'CTU',   365, 90,  'Annual Inspection',    'CT unit, injector head, BHA'),

  -- Miscellaneous
  ('Hand Tools & Torque',      'HT',    365, 90,  'Annual Inspection',    'Tongs, wrenches, torque equipment'),
  ('Camp & Surface Facilities','CSF',   365, 90,  'Annual Inspection',    'Generators, HVAC, water tanks')

ON CONFLICT (code) DO NOTHING;


-- ────────────────────────────────────────────────────────────
--  4. SAMPLE ASSETS (10 representative equipment records)
--  Covers the most critical categories in Oil & Gas drilling
-- ────────────────────────────────────────────────────────────

-- Get company id for NDC
DO $$
DECLARE
  v_ndc_id   UUID;
  v_edc_id   UUID;
  v_rig1_id  UUID;
  v_rig2_id  UUID;
  v_rig3_id  UUID;
  v_yard_id  UUID;
  v_bop_cat  UUID;
  v_lift_cat UUID;
  v_ds_cat   UUID;
  v_pv_cat   UUID;
  v_sv_cat   UUID;
  v_tds_cat  UUID;
BEGIN
  SELECT id INTO v_ndc_id   FROM companies  WHERE short_code = 'NDC';
  SELECT id INTO v_edc_id   FROM companies  WHERE short_code = 'EDC';
  SELECT id INTO v_rig1_id  FROM locations  WHERE code = 'RIG-01';
  SELECT id INTO v_rig2_id  FROM locations  WHERE code = 'RIG-02';
  SELECT id INTO v_rig3_id  FROM locations  WHERE code = 'RIG-03';
  SELECT id INTO v_yard_id  FROM locations  WHERE code = 'YARD-CAI';
  SELECT id INTO v_bop_cat  FROM categories WHERE code = 'BOP';
  SELECT id INTO v_lift_cat FROM categories WHERE code = 'LIFT';
  SELECT id INTO v_ds_cat   FROM categories WHERE code = 'DS';
  SELECT id INTO v_pv_cat   FROM categories WHERE code = 'PV';
  SELECT id INTO v_sv_cat   FROM categories WHERE code = 'SV';
  SELECT id INTO v_tds_cat  FROM categories WHERE code = 'TDS';

  INSERT INTO assets
    (name, category_id, category_name, manufacturer, model, serial_number,
     location_id, location_code, location_name,
     status, company_id, acquisition_date, supplier_name)
  VALUES
    ('BOP Stack 13-5/8" 10K',   v_bop_cat,  'BOP Equipment',   'Cameron',     'Type U',        'CAM-2019-00142', v_rig1_id, 'RIG-01', 'Rig 1  — Western Desert', 'Active', v_ndc_id, '2019-03-15', 'Cameron Egypt'),
    ('BOP Stack 11" 5K',        v_bop_cat,  'BOP Equipment',   'Hydril',      'GXL',           'HYD-2020-00891', v_rig2_id, 'RIG-02', 'Rig 2  — Sinai',          'Active', v_ndc_id, '2020-06-01', 'Hydril Middle East'),
    ('Top Drive 500T',          v_tds_cat,  'Top Drive System','Canrig',      '1275AC',        'CNR-2021-00034', v_rig3_id, 'RIG-03', 'Rig 3  — Gulf of Suez',   'Active', v_ndc_id, '2021-01-10', 'Canrig Drilling Tech'),
    ('Air Hoist 5T',            v_lift_cat, 'Lifting Equipment','Ingersoll Rand','ML500',       'IR-2020-05512',  v_rig1_id, 'RIG-01', 'Rig 1  — Western Desert', 'Active', v_edc_id, '2020-09-20', 'IR Egypt'),
    ('Crown Block 500T',        v_lift_cat, 'Lifting Equipment','National Oilwell','CB-500',    'NOV-2018-00221', v_rig3_id, 'RIG-03', 'Rig 3  — Gulf of Suez',   'Active', v_ndc_id, '2018-05-12', 'NOV Egypt'),
    ('Drill Pipe 5" DP Grade E',v_ds_cat,   'Drill String',    'Tenaris',     'TenarisHydril', 'TEN-2022-1000',  v_rig1_id, 'RIG-01', 'Rig 1  — Western Desert', 'Active', v_ndc_id, '2022-02-01', 'Tenaris'),
    ('Mud Gas Separator',       v_pv_cat,   'Pressure Vessels','CROSCO',      'MGS-24',        'CRS-2019-00045', v_rig2_id, 'RIG-02', 'Rig 2  — Sinai',          'Active', v_edc_id, '2019-11-30', 'CROSCO'),
    ('IBOP Safety Valve 5"',    v_sv_cat,   'Safety Valves',   'Smith Bits',  'IBOP-5',        'SMB-2021-00312', v_rig1_id, 'RIG-01', 'Rig 1  — Western Desert', 'Active', v_ndc_id, '2021-07-15', 'Smith International'),
    ('BOP Stack 13-3/8" 3K',    v_bop_cat,  'BOP Equipment',   'Shaffer',     'LWS',           'SHA-2017-00098', v_yard_id, 'YARD-CAI','Cairo Laydown Yard',     'Standby',v_edc_id, '2017-04-01', 'Shaffer NOV'),
    ('Travelling Block 350T',   v_lift_cat, 'Lifting Equipment','Varco',       'TB-350',        'VAR-2020-00667', v_rig2_id, 'RIG-02', 'Rig 2  — Sinai',          'Active', v_ndc_id, '2020-03-18', 'Varco International')
  ON CONFLICT (asset_id) DO NOTHING;

END $$;


-- ────────────────────────────────────────────────────────────
--  5. SAMPLE CERTIFICATES
--  Spread across Valid / Expiring Soon / Expired statuses
--  so the dashboard shows meaningful data immediately
-- ────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_asset_id UUID;
BEGIN

  -- BOP Stack 13-5/8" → Valid cert
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'CAM-2019-00142';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'BOP Pressure Test', 'Bureau Veritas',
       CURRENT_DATE - 60,
       CURRENT_DATE + 305,
       'https://certs.example.com/CERT-BOP-CAM-001',
       'BV-2025-BOP-0142', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- BOP Stack 11" → Expiring Soon (within 90 days)
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'HYD-2020-00891';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'BOP Pressure Test', 'Lloyd''s Register',
       CURRENT_DATE - 290,
       CURRENT_DATE + 75,
       'https://certs.example.com/CERT-BOP-HYD-002',
       'LR-2025-BOP-0891', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- Top Drive 500T → Expiring Soon (45 days)
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'CNR-2021-00034';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'Annual Inspection', 'SGS',
       CURRENT_DATE - 320,
       CURRENT_DATE + 45,
       'https://certs.example.com/CERT-TDS-CNR-003',
       'SGS-2025-TDS-0034', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- Air Hoist → EXPIRED
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'IR-2020-05512';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'Load Test', 'Bureau Veritas',
       CURRENT_DATE - 380,
       CURRENT_DATE - 15,
       'https://certs.example.com/CERT-LIFT-IR-004',
       'BV-2024-LIFT-5512', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- Crown Block → Valid
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'NOV-2018-00221';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'Load Test', 'Lloyd''s Register',
       CURRENT_DATE - 30,
       CURRENT_DATE + 335,
       'https://certs.example.com/CERT-LIFT-NOV-005',
       'LR-2025-LIFT-0221', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- Drill Pipe → No cert (new equipment, needs first cert)
  -- Left as No Certificate deliberately

  -- Mud Gas Separator → Expiring Soon (60 days)
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'CRS-2019-00045';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'Pressure Test', 'SGS',
       CURRENT_DATE - 305,
       CURRENT_DATE + 60,
       'https://certs.example.com/CERT-PV-CRS-006',
       'SGS-2025-PV-0045', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- IBOP Safety Valve → Valid
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'SMB-2021-00312';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'Pressure Test', 'Bureau Veritas',
       CURRENT_DATE - 10,
       CURRENT_DATE + 355,
       'https://certs.example.com/CERT-SV-SMB-007',
       'BV-2025-SV-0312', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- BOP in Yard → EXPIRED (stacked, needs recert before deployment)
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'SHA-2017-00098';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'BOP Pressure Test', 'Bureau Veritas',
       CURRENT_DATE - 400,
       CURRENT_DATE - 35,
       'https://certs.example.com/CERT-BOP-SHA-008',
       'BV-2024-BOP-0098', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

  -- Travelling Block → Valid
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'VAR-2020-00667';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO certificates
      (asset_id, inspection_type, issued_by, issue_date, expiry_date,
       cert_link, cert_number, alert_days, is_current)
    VALUES
      (v_asset_id, 'Load Test', 'Lloyd''s Register',
       CURRENT_DATE - 45,
       CURRENT_DATE + 320,
       'https://certs.example.com/CERT-LIFT-VAR-009',
       'LR-2025-LIFT-0667', 90, TRUE)
    ON CONFLICT DO NOTHING;
  END IF;

END $$;


-- ────────────────────────────────────────────────────────────
--  6. SAMPLE INSPECTIONS (upcoming schedule)
-- ────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_asset_id UUID;
  v_loc_id   UUID;
BEGIN

  SELECT id INTO v_loc_id FROM locations WHERE code = 'RIG-02';

  -- BOP 11" — schedule pressure test (expiring soon)
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'HYD-2020-00891';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO inspections
      (asset_id, asset_name, scheduled_date, inspection_type,
       inspector_company, location_id, location_name, status, notes)
    VALUES
      (v_asset_id, 'BOP Stack 11" 5K',
       CURRENT_DATE + 30,
       'BOP Pressure Test',
       'Bureau Veritas', v_loc_id, 'Rig 2  — Sinai',
       'Scheduled', 'Scheduled due to cert expiry in 75 days')
    ON CONFLICT DO NOTHING;
  END IF;

  -- Top Drive — Annual inspection overdue
  SELECT id INTO v_asset_id FROM assets WHERE serial_number = 'CNR-2021-00034';
  SELECT id INTO v_loc_id   FROM locations WHERE code = 'RIG-03';
  IF v_asset_id IS NOT NULL THEN
    INSERT INTO inspections
      (asset_id, asset_name, scheduled_date, inspection_type,
       inspector_company, location_id, location_name, status, notes)
    VALUES
      (v_asset_id, 'Top Drive 500T',
       CURRENT_DATE - 5,
       'Annual Inspection',
       'SGS', v_loc_id, 'Rig 3  — Gulf of Suez',
       'Overdue', 'Cert expiring in 45 days — urgent')
    ON CONFLICT DO NOTHING;
  END IF;

END $$;


-- ────────────────────────────────────────────────────────────
--  VERIFICATION QUERIES
--  Run these to confirm seed data loaded correctly
-- ────────────────────────────────────────────────────────────
/*
SELECT COUNT(*) AS companies   FROM companies;
SELECT COUNT(*) AS locations   FROM locations;
SELECT COUNT(*) AS categories  FROM categories;
SELECT COUNT(*) AS assets      FROM assets;
SELECT COUNT(*) AS certificates FROM certificates;
SELECT COUNT(*) AS inspections FROM inspections;

-- Dashboard KPIs
SELECT * FROM vw_dashboard_kpis;

-- Equipment status overview
SELECT asset_id, name, cert_status, cert_expiry_date,
       (cert_expiry_date - CURRENT_DATE) AS days_remaining,
       location_name
FROM vw_equipment_status
ORDER BY days_remaining ASC NULLS LAST;

-- Cert expiry report
SELECT cert_id, asset_name, inspection_type,
       expiry_date, days_remaining, cert_status, cert_link
FROM vw_cert_expiry_report;
*/

-- ============================================================
--  END OF 002_seed.sql
--  Next file: _worker.js (Cloudflare Worker API)
-- ============================================================
