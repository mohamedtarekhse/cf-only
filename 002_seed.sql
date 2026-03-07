-- ══════════════════════════════════════════════════════════════════════════════
--  Seed Data — run AFTER 001_schema.sql
--  Uses ON CONFLICT DO UPDATE so re-running is safe and fixes any bad data
-- ══════════════════════════════════════════════════════════════════════════════

-- ─── COMPANIES ────────────────────────────────────────────────────────────────
INSERT INTO companies (id,name,type,country,contact,email,status) VALUES
  ('CMP001','Arabian Drilling Company',   'Drilling Contractor','Saudi Arabia','Khalid Al-Rashid',  'k.rashid@adc.com.sa',       'Active'),
  ('CMP002','NABORS Industries',          'Drilling Contractor','USA',         'James Wilson',       'j.wilson@nabors.com',        'Active'),
  ('CMP003','Patterson-UTI Energy',       'Drilling Contractor','USA',         'Sarah Johnson',      's.johnson@patenergy.com',     'Active'),
  ('CMP004','Al-Khafji Joint Operations', 'Operator',          'Kuwait',       'Mohammed Al-Khafji', 'm.khafji@kjo.com',            'Active'),
  ('CMP005','Parker Drilling',            'Drilling Contractor','USA',         'Mike Parker',        'm.parker@parkerdrilling.com', 'Inactive')
ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, type=EXCLUDED.type, country=EXCLUDED.country,
  contact=EXCLUDED.contact, email=EXCLUDED.email, status=EXCLUDED.status;

-- ─── RIGS ─────────────────────────────────────────────────────────────────────
INSERT INTO rigs (id,name,type,company,location,depth,hp,status) VALUES
  ('RIG01','Rig 1', 'AC Drive',   'Arabian Drilling Company',   'Ghawar Field – Block A',    '25,000 ft',2000,'Active'),
  ('RIG02','Rig 2', 'Mechanical', 'Arabian Drilling Company',   'Ghawar Field – Block B',    '20,000 ft',1500,'Active'),
  ('RIG03','Rig 3', 'Electric',   'NABORS Industries',          'Permian Basin, TX',         '30,000 ft',3000,'Active'),
  ('RIG04','Rig 4', 'SCR',        'NABORS Industries',          'Permian Basin – South',     '28,000 ft',2500,'Maintenance'),
  ('RIG05','Rig 5', 'AC Drive',   'Patterson-UTI Energy',       'DJ Basin, CO',              '22,000 ft',2000,'Active'),
  ('RIG06','Rig 6', 'SCR',        'Patterson-UTI Energy',       'Eagle Ford, TX',            '18,000 ft',1500,'Active'),
  ('RIG07','Rig 7', 'Mechanical', 'Al-Khafji Joint Operations', 'Khafji Field – North',      '18,000 ft',1200,'Active'),
  ('RIG08','Rig 8', 'AC Drive',   'Al-Khafji Joint Operations', 'Khafji Field – South',      '20,000 ft',1800,'Standby'),
  ('RIG09','Rig 9', 'Electric',   'Arabian Drilling Company',   'Safaniyah Offshore Tie-in', '24,000 ft',2200,'Active'),
  ('RIG10','Rig 10','SCR',        'Parker Drilling',            'Empty Quarter – Block C',   '26,000 ft',2000,'Active'),
  ('RIG11','Rig 11','AC Drive',   'Parker Drilling',            'Empty Quarter – Block D',   '24,000 ft',2000,'Maintenance'),
  ('RIG12','Rig 12','Mechanical', 'Arabian Drilling Company',   'Abqaiq Field',              '21,000 ft',1600,'Active'),
  ('RIG13','Rig 13','Electric',   'NABORS Industries',          'Haradh Gas Field',          '32,000 ft',3000,'Active'),
  ('RIG14','Rig 14','AC Drive',   'Patterson-UTI Energy',       'Hawiyah Gas Field',         '28,000 ft',2500,'Standby')
ON CONFLICT (id) DO UPDATE SET
  name=EXCLUDED.name, type=EXCLUDED.type, company=EXCLUDED.company,
  location=EXCLUDED.location, depth=EXCLUDED.depth, hp=EXCLUDED.hp, status=EXCLUDED.status;

-- ─── CONTRACTS ────────────────────────────────────────────────────────────────
INSERT INTO contracts (id,company,rig,value,start_date,end_date,status) VALUES
  ('CON-2024-001','Arabian Drilling Company',  'ADC Rig #7',        4800000,'2024-01-15','2025-01-14','Active'),
  ('CON-2024-002','NABORS Industries',         'NABORS 1250-E',     3200000,'2024-03-01','2025-03-01','Active'),
  ('CON-2024-003','Al-Khafji Joint Operations','KJO Land Rig #3',   6100000,'2023-07-01','2024-07-01','Expired'),
  ('CON-2025-001','Patterson-UTI Energy',      'Patterson Rig #55', 1950000,'2025-01-10','2026-01-10','Pending')
ON CONFLICT (id) DO UPDATE SET
  company=EXCLUDED.company, rig=EXCLUDED.rig, value=EXCLUDED.value,
  start_date=EXCLUDED.start_date, end_date=EXCLUDED.end_date, status=EXCLUDED.status;

-- ─── ASSETS ───────────────────────────────────────────────────────────────────
INSERT INTO assets (asset_id,name,category,company,rig_name,location,status,value,acquisition_date,serial,notes,last_inspection,inspection_type,cert_link) VALUES
  ('AST-001','Top Drive System',          'Well Head Equipment',    'Arabian Drilling Company',   'Rig 1', 'Assigned Rig', 'Contracted', 1200000,'2021-03-15','TD-7821',   'High-capacity 1000T top drive',          '2024-10-01','Cat III',                 'https://example.com/cert/AST-001'),
  ('AST-002','BOP Stack 18-3/4"',         'Well Control Equipment', 'Arabian Drilling Company',   'Rig 1', 'Assigned Rig', 'Contracted',  850000,'2020-07-20','BOP-4422',  'Cameron BOP Stack',                      '2024-09-15','Pressure Test',           'https://example.com/cert/AST-002'),
  ('AST-003','Derrick Structure 142''',   'Handling Tools',         'Arabian Drilling Company',   'Rig 2', 'Workshop',     'Active',     2100000,'2018-05-01','DRK-0078',  'IRI 142ft mast structure',               '2024-08-20','Cat IV',                  ''),
  ('AST-004','Mud Pumps (3x)',             'Well Control Equipment', 'Arabian Drilling Company',   'Rig 2', 'Sukhna Yard',  'Maintenance', 620000,'2019-11-05','MP-1103',   'National 14-P-220 pumps',                '2024-07-10','Pressure Test',           'https://example.com/cert/AST-004'),
  ('AST-005','Drawworks 1500HP',          'Handling Tools',         'NABORS Industries',          'Rig 3', 'Assigned Rig', 'Active',     1800000,'2020-08-12','DW-3312',   'National 1500HP drawworks',              '2024-11-01','Calibration',             'https://example.com/cert/AST-005'),
  ('AST-006','CAT 3516 Generator Set',    'Well Head Equipment',    'NABORS Industries',          'Rig 3', 'Free Zone',    'Active',      480000,'2022-01-10','GEN-7712',  '2000kW prime power generator',           '2024-06-15','Calibration',             ''),
  ('AST-007','Casing Running Tool',       'Handling Tools',         'NABORS Industries',          'Rig 4', 'Workshop',     'Inactive',    130000,'2020-03-15','CRT-9910',  'Hydraulic CRT for 13-3/8" casing',      '2024-05-20','Cat III',                 'https://example.com/cert/AST-007'),
  ('AST-008','H2S Detection System',      'Well Control Equipment', 'NABORS Industries',          'Rig 4', 'Assigned Rig', 'Active',       75000,'2022-06-15','SFT-2291',  'Multi-point H2S gas detection',          '2024-10-20','Calibration',             ''),
  ('AST-009','Rotary Table 37.5"',        'Well Head Equipment',    'Patterson-UTI Energy',       'Rig 5', 'Assigned Rig', 'Active',      320000,'2021-06-20','RT-5501',   '37.5" rotary table 500T capacity',       '2024-09-01','Cat IV',                  'https://example.com/cert/AST-009'),
  ('AST-010','Emergency Fire Suppression','Well Control Equipment', 'Patterson-UTI Energy',       'Rig 5', 'Sukhna Yard',  'Active',       88000,'2023-05-20','SFT-4451',  'Dry chemical fire suppression',          NULL,        '',                        ''),
  ('AST-011','Tubular String 5" DP',      'Tubular',                'Patterson-UTI Energy',       'Rig 6', 'Free Zone',    'Active',      145000,'2021-09-01','TUB-8811',  '5" drill pipe string',                   '2024-11-10','Tubular Inspection DS1',  'https://example.com/cert/AST-011'),
  ('AST-012','Rig Mover & Substructure',  'Handling Tools',         'Patterson-UTI Energy',       'Rig 6', 'Assigned Rig', 'Active',      950000,'2019-03-10','RMV-0601',  'Self-propelled walking system',          '2024-08-01','Cat III',                 ''),
  ('AST-013','Drill Collar 8" Slick DC',  'Tubular',                'Al-Khafji Joint Operations', 'Rig 7', 'Sukhna Yard',  'Active',       95000,'2023-02-28','DC-0341',   '8" slick drill collars x12',             '2024-10-15','Wall Thickness',           'https://example.com/cert/AST-013'),
  ('AST-014','Heavy Weight Drill Pipe',   'Tubular',                'Al-Khafji Joint Operations', 'Rig 7', 'Free Zone',    'Maintenance',  42000,'2021-11-15','HWDP-1102', '5" HWDP 30 joints',                      '2024-09-20','Tubular Inspection DS1',  'https://example.com/cert/AST-014'),
  ('AST-015','Drilling Jars – Hydraulic', 'Well Control Equipment', 'Al-Khafji Joint Operations', 'Rig 8', 'Assigned Rig', 'Active',      210000,'2022-12-01','JAR-3301',  'Hydraulic drilling jars set',            '2024-07-05','Pressure Test',           ''),
  ('AST-016','Wellhead Christmas Tree',   'Well Head Equipment',    'Arabian Drilling Company',   'Rig 9', 'Workshop',     'Active',     1050000,'2022-04-18','WHD-9901',  'Wellhead Christmas tree 5K psi',         '2024-11-05','Pressure Test',           'https://example.com/cert/AST-016'),
  ('AST-017','Accumulator Unit 120 Gal',  'Well Control Equipment', 'Arabian Drilling Company',   'Rig 9', 'Sukhna Yard',  'Active',      185000,'2021-07-22','ACC-0091',  '120 gal hydraulic accumulator',          '2024-08-12','Pressure Test',           ''),
  ('AST-018','Centrifugal Pump Set',      'Well Control Equipment', 'Parker Drilling',            'Rig 10','Workshop',     'Active',      160000,'2023-01-15','CP-1001',   '3x centrifugal charge pumps',            '2024-07-22','Pressure Test',           ''),
  ('AST-019','SCR Control House',         'Well Head Equipment',    'Parker Drilling',            'Rig 11','Sukhna Yard',  'Maintenance', 420000,'2020-09-30','SCR-1101',  'Silicon controlled rectifier house',     '2024-06-10','Calibration',             ''),
  ('AST-020','BOP Annular 13-5/8"',       'Well Control Equipment', 'Arabian Drilling Company',   'Rig 12','Assigned Rig', 'Active',      740000,'2021-02-14','BOP-1201',  '13-5/8" 10K annular BOP',                '2024-11-01','Pressure Test',           'https://example.com/cert/AST-020'),
  ('AST-021','Tubing String 2-7/8"',      'Tubular',                'Arabian Drilling Company',   'Rig 12','Free Zone',    'Active',       95000,'2022-08-05','TUB-1201',  '2-7/8" EUE tubing 200 joints',           '2024-10-05','Tubular Inspection DS1',  'https://example.com/cert/AST-021'),
  ('AST-022','Iron Roughneck',            'Handling Tools',         'NABORS Industries',          'Rig 13','Assigned Rig', 'Active',      580000,'2022-11-20','IRN-1301',  'Automated iron roughneck 60k ft-lb',     '2024-09-12','Cat III',                 ''),
  ('AST-023','Shale Shaker 4-Panel',      'Well Control Equipment', 'Patterson-UTI Energy',       'Rig 14','Workshop',     'Standby',     220000,'2023-06-01','SS-1401',   '4-panel linear motion shaker',           NULL,        '',                        ''),
  ('AST-024','Casing Hanger Tool',        'Well Head Equipment',    'Patterson-UTI Energy',       'Rig 14','Sukhna Yard',  'Active',      195000,'2022-03-10','CSH-1401',  'Casing hanger running tool',             '2024-08-30','Cat IV',                  'https://example.com/cert/AST-024')
ON CONFLICT (asset_id) DO UPDATE SET
  name=EXCLUDED.name, category=EXCLUDED.category, company=EXCLUDED.company,
  rig_name=EXCLUDED.rig_name, location=EXCLUDED.location, status=EXCLUDED.status,
  value=EXCLUDED.value, acquisition_date=EXCLUDED.acquisition_date,
  serial=EXCLUDED.serial, notes=EXCLUDED.notes,
  last_inspection=EXCLUDED.last_inspection, inspection_type=EXCLUDED.inspection_type,
  cert_link=EXCLUDED.cert_link;

-- ─── CONTRACT ↔ ASSET ─────────────────────────────────────────────────────────
INSERT INTO contract_assets (contract_id,asset_id) VALUES
  ('CON-2024-001','AST-001'),('CON-2024-001','AST-002'),
  ('CON-2024-001','AST-003'),('CON-2024-001','AST-016'),
  ('CON-2024-002','AST-005'),('CON-2024-002','AST-006'),('CON-2024-002','AST-022'),
  ('CON-2024-003','AST-013'),('CON-2024-003','AST-014'),('CON-2024-003','AST-015'),
  ('CON-2025-001','AST-009'),('CON-2025-001','AST-023')
ON CONFLICT DO NOTHING;

-- ─── BOM ITEMS ────────────────────────────────────────────────────────────────
-- NOTE: BOM-016..020 belong to AST-004 (Mud Pumps), NOT AST-003 (Derrick)
--       BOM-021..026 belong to AST-006 (Generator Set), NOT AST-005 (Drawworks)
INSERT INTO bom_items (id,asset_id,parent_id,name,part_no,type,serial,manufacturer,qty,uom,unit_cost,lead_time,status,notes) VALUES
  -- Top Drive (AST-001)
  ('BOM-001','AST-001',NULL,    'Top Drive System',         'TD-7821',   'Serialized','TD-7821-A',  'NOV',             1,'EA', 1200000,180,'Active',    'Complete top drive assembly 1000T'),
  ('BOM-002','AST-001','BOM-001','Main Electric Motor',     'MOT-2201',  'Serialized','MOT-2201-X', 'Siemens',         2,'EA',   85000, 90,'Active',    'AC induction motor 750kW each'),
  ('BOM-003','AST-001','BOM-001','Gearbox Assembly',        'GBX-5501',  'Serialized','GBX-5501-B', 'NOV',             1,'EA',  120000,120,'Active',    '2-speed planetary gearbox'),
  ('BOM-004','AST-001','BOM-003','Planetary Gear Set',      'PGS-3301',  'Serialized','PGS-3301-C', 'NOV',             1,'SET',  35000, 60,'Active',    'Planetary gear set for 2nd stage'),
  ('BOM-005','AST-001','BOM-003','Gear Lubricant ISO 320',  'LUB-ISO320','Bulk',       NULL,         'Shell',          50,'L',       8,  7,'Active',    'Synthetic gear oil ISO VG 320'),
  ('BOM-006','AST-001','BOM-001','Hydraulic Swivel',        'SWV-0871',  'Serialized','SWV-0871-D', 'Smith International',1,'EA', 95000, 60,'Active',   '600 GPM hydraulic swivel'),
  ('BOM-007','AST-001','BOM-001','Hydraulic Seal Kit',      'SEAL-K201', 'Bulk',       NULL,         'Parker',          5,'KIT',   420, 14,'Active',    'Annual seal replacement kit'),
  ('BOM-008','AST-001','BOM-001','Pipe Handler Arm',        'PHA-4410',  'Serialized','PHA-4410-A', 'NOV',             1,'EA',   48000, 90,'Active',    'Hydraulic pipe handler arm'),
  ('BOM-009','AST-001','BOM-008','Mounting Bolts M42',      'BOLT-M42',  'Bulk',       NULL,         'Würth',          32,'PCS',    12,  3,'Active',    'Grade 10.9 hex bolts M42×150'),
  -- BOP Stack (AST-002)
  ('BOM-010','AST-002',NULL,    'BOP Stack 18-3/4"',        'BOP-4422',  'Serialized','BOP-4422-M', 'Cameron',         1,'EA',  850000,365,'Active',    '18-3/4" 15K psi BOP Stack'),
  ('BOM-011','AST-002','BOM-010','Annular BOP',             'ANN-1801',  'Serialized','ANN-1801-A', 'Cameron',         1,'EA',  180000,120,'Active',    '18-3/4" spherical annular BOP'),
  ('BOM-012','AST-002','BOM-010','Double Ram BOP',          'RAM-D802',  'Serialized','RAM-D802-B', 'Cameron',         1,'EA',  220000,180,'Active',    'Double ram BOP 18-3/4" 15K'),
  ('BOM-013','AST-002','BOM-012','Ram Packer Rubber',       'PKR-5501',  'Bulk',       NULL,         'Cameron',         4,'EA',   3500, 30,'Active',    '5" & 5-1/2" combination packer'),
  ('BOM-014','AST-002','BOM-010','BOP Control Unit',        'BCU-7701',  'Serialized','BCU-7701-C', 'Koomey',          1,'EA',   95000, 60,'Active',    'Hydraulic BOP control unit'),
  ('BOM-015','AST-002','BOM-014','Hydraulic Fluid MIL-H',   'HYD-MILH',  'Bulk',       NULL,         'Total',         200,'L',       6,  5,'Active',    'MIL-H-5606 hydraulic fluid'),
  -- Mud Pumps (AST-004) ← FIXED: was wrongly AST-003 in original seed
  ('BOM-016','AST-004',NULL,    'Mud Pump Assembly (3x)',   'MP-1103',   'Serialized','MP-1103-SET','National',         3,'EA',  620000,180,'Active',    'National 14-P-220 triplex mud pumps'),
  ('BOM-017','AST-004','BOM-016','Liner Assembly 7"',       'LNR-7IN',   'Serialized', NULL,         'National',        6,'EA',    4200, 21,'Active',    '7" ceramic liner, wear-resistant'),
  ('BOM-018','AST-004','BOM-016','Piston / Rod Assembly',   'PST-R201',  'Serialized', NULL,         'National',        9,'EA',    1800, 14,'Maintenance','3 per pump, chrome-plated rods'),
  ('BOM-019','AST-004','BOM-016','Valve & Seat Kit',        'VLV-SK31',  'Bulk',        NULL,        'National',       12,'SET',   650,  7,'Active',    'Suction & discharge valve kits'),
  ('BOM-020','AST-004','BOM-016','Packing Seal Kit',        'PCK-S220',  'Bulk',        NULL,        'Garlock',        18,'KIT',   280,  5,'Active',    'Piston packing sets per pump'),
  -- Generator Set (AST-006) ← FIXED: was wrongly AST-005 in original seed
  ('BOM-021','AST-006',NULL,    'CAT 3516 Generator Set',   'GEN-7712',  'Serialized','GEN-7712-A', 'Caterpillar',     1,'EA',  480000,240,'Active',    '2000kW prime power genset'),
  ('BOM-022','AST-006','BOM-021','CAT 3516 Engine Block',   'ENG-3516B', 'Serialized','3516B-9921', 'Caterpillar',     1,'EA',  210000,120,'Active',    'V16 diesel engine block assembly'),
  ('BOM-023','AST-006','BOM-021','Alternator SR4B',         'ALT-SR4B',  'Serialized','SR4B-5521',  'Caterpillar',     1,'EA',   95000, 90,'Active',    '2250 kVA SR4B brushless alternator'),
  ('BOM-024','AST-006','BOM-021','Engine Oil 15W-40',       'OIL-1540',  'Bulk',        NULL,        'Shell Rimula',  300,'L',     4.5,  2,'Active',    'CAT DEOTF spec diesel engine oil'),
  ('BOM-025','AST-006','BOM-021','Fuel Filter Set',         'FLT-F401',  'Bulk',        NULL,        'Caterpillar',     6,'EA',    85,   3,'Active',    'Primary & secondary fuel filters'),
  ('BOM-026','AST-006','BOM-021','Air Filter Assembly',     'FLT-A201',  'Bulk',        NULL,        'Donaldson',       4,'EA',   120,   5,'Active',    'Heavy-duty radial seal air filters')
ON CONFLICT (id) DO UPDATE SET
  asset_id=EXCLUDED.asset_id, parent_id=EXCLUDED.parent_id, name=EXCLUDED.name,
  part_no=EXCLUDED.part_no, type=EXCLUDED.type, serial=EXCLUDED.serial,
  manufacturer=EXCLUDED.manufacturer, qty=EXCLUDED.qty, uom=EXCLUDED.uom,
  unit_cost=EXCLUDED.unit_cost, lead_time=EXCLUDED.lead_time,
  status=EXCLUDED.status, notes=EXCLUDED.notes;

-- ─── CERTIFICATES ─────────────────────────────────────────────────────────────
INSERT INTO certificates (cert_id,asset_id,inspection_type,last_inspection,next_inspection,validity_days,alert_days,cert_link,notes) VALUES
  ('CERT-001','AST-001','Cat III',               '2024-10-01','2025-10-01',365,30,'https://example.com/cert/AST-001',''),
  ('CERT-002','AST-002','Pressure Test',         '2024-09-15','2025-09-15',365,30,'https://example.com/cert/AST-002',''),
  ('CERT-003','AST-003','Cat IV',                '2024-08-20','2025-08-20',365,30,'',''),
  ('CERT-004','AST-004','Pressure Test',         '2024-07-10','2025-07-10',365,30,'https://example.com/cert/AST-004',''),
  ('CERT-005','AST-005','Calibration',           '2024-11-01','2025-11-01',365,30,'https://example.com/cert/AST-005',''),
  ('CERT-006','AST-006','Calibration',           '2024-06-15','2025-06-15',365,30,'',''),
  ('CERT-007','AST-007','Cat III',               '2024-05-20','2025-05-20',365,30,'https://example.com/cert/AST-007',''),
  ('CERT-008','AST-008','Calibration',           '2024-10-20','2025-10-20',365,30,'',''),
  ('CERT-009','AST-009','Cat IV',                '2024-09-01','2025-09-01',365,30,'https://example.com/cert/AST-009',''),
  ('CERT-010','AST-011','Tubular Inspection DS1','2024-11-10','2025-11-10',365,30,'https://example.com/cert/AST-011',''),
  ('CERT-011','AST-012','Cat III',               '2024-08-01','2025-08-01',365,30,'',''),
  ('CERT-012','AST-013','Wall Thickness',        '2024-10-15','2025-10-15',365,30,'https://example.com/cert/AST-013',''),
  ('CERT-013','AST-014','Tubular Inspection DS1','2024-09-20','2025-09-20',365,30,'https://example.com/cert/AST-014',''),
  ('CERT-014','AST-016','Pressure Test',         '2024-11-05','2025-11-05',365,30,'https://example.com/cert/AST-016',''),
  ('CERT-015','AST-017','Pressure Test',         '2024-08-12','2025-08-12',365,30,'',''),
  ('CERT-016','AST-018','Pressure Test',         '2024-07-22','2025-07-22',365,30,'',''),
  ('CERT-017','AST-019','Calibration',           '2024-06-10','2025-06-10',365,30,'',''),
  ('CERT-018','AST-020','Pressure Test',         '2024-11-01','2025-11-01',365,30,'https://example.com/cert/AST-020',''),
  ('CERT-019','AST-021','Tubular Inspection DS1','2024-10-05','2025-10-05',365,30,'https://example.com/cert/AST-021',''),
  ('CERT-020','AST-022','Cat III',               '2024-09-12','2025-09-12',365,30,'',''),
  ('CERT-021','AST-024','Cat IV',                '2024-08-30','2025-08-30',365,30,'https://example.com/cert/AST-024','')
ON CONFLICT (cert_id) DO UPDATE SET
  inspection_type=EXCLUDED.inspection_type, last_inspection=EXCLUDED.last_inspection,
  next_inspection=EXCLUDED.next_inspection, validity_days=EXCLUDED.validity_days,
  alert_days=EXCLUDED.alert_days, cert_link=EXCLUDED.cert_link, notes=EXCLUDED.notes;

-- ─── MAINTENANCE SCHEDULES ────────────────────────────────────────────────────
-- status stores ONLY: Scheduled / In Progress / Completed / Cancelled
-- Overdue / Due Soon are COMPUTED by server from next_due vs today
INSERT INTO maintenance_schedules (id,asset_id,task,type,freq,last_done,next_due,tech,hours,cost,priority,status,alert_days,notes) VALUES
  ('PM-001','AST-001','Top Drive Annual Inspection',   'Inspection',        365,'2024-03-15','2025-03-15','Baker Hughes Team',    16,8500, 'Critical','Scheduled', 30,'Full strip-down inspection per NOV manual ch.7.'),
  ('PM-002','AST-001','Gearbox Oil Change',            'Oil Change',         90,'2024-11-01','2025-01-30','Mohammed Al-Farsi',     4,1200, 'High',    'Scheduled', 14,'Drain and replace ISO 320 gear oil.'),
  ('PM-003','AST-002','BOP Pressure Test',             'Pressure Test',     180,'2024-07-10','2025-01-10','Bureau Veritas',         8,4500, 'Critical','Scheduled', 30,'15K psi pressure test per API 16A.'),
  ('PM-004','AST-002','Ram Packer Inspection',         'Inspection',         90,'2024-10-15','2025-01-13','Omar Hassan',            6,2200, 'High',    'Scheduled', 14,'Inspect and replace worn ram packers.'),
  ('PM-005','AST-004','Mud Pump Liner Inspection',     'Inspection',         30,'2024-12-20','2025-01-19','Ahmed Khalid',           3, 800, 'High',    'Scheduled',  7,'Inspect liner wear. Replace if >15% worn.'),
  ('PM-006','AST-004','Valve & Seat Replacement',      'Filter Replacement', 60,'2024-11-25','2025-01-24','Ahmed Khalid',           5,3200, 'High',    'Scheduled',  7,'Replace suction and discharge valves.'),
  ('PM-007','AST-003','Derrick Structural Inspection', 'Inspection',        365,'2024-02-01','2025-02-01','SGS Inspection',        12,6000, 'Critical','Scheduled', 30,'Full visual and NDT inspection per API 4F.'),
  ('PM-008','AST-006','Generator Oil & Filter Change', 'Oil Change',        250,'2024-10-01','2025-06-08','CAT Dealer Team',        6,2800, 'Normal',  'Scheduled', 14,'250-hour PM service.'),
  ('PM-009','AST-006','Generator Load Bank Test',      'Electrical Check',   90,'2024-11-15','2025-02-13','Hamdan Ali',             4,1500, 'Normal',  'Scheduled', 14,'Full load bank test at 100% rated capacity.'),
  ('PM-010','AST-008','H2S Sensor Calibration',        'Calibration',        30,'2024-12-28','2025-01-27','Safety Officer',          2, 400, 'Critical','Scheduled',  7,'Calibrate all H2S sensors with certified gas.'),
  ('PM-011','AST-008','SCBA Equipment Inspection',     'Safety Check',      180,'2024-07-01','2025-01-01','Safety Officer',          3, 600, 'Critical','Scheduled', 14,'Inspect all 30 SCBA units.'),
  ('PM-012','AST-006','VSAT Antenna Alignment',        'General Service',   180,'2024-06-15','2024-12-15','Hughes Network Tech',     3,1800, 'Normal',  'Completed', 14,'Check and realign satellite dish.'),
  ('PM-013','AST-015','Jar Tool Function Test',        'Inspection',         90,'2024-10-20','2025-01-18','Fishing Tool Engr',       4,2000, 'High',    'Scheduled',  7,'Function test hydraulic jars at rated load.'),
  ('PM-014','AST-004','Triplex Pump Packing Change',   'General Service',    45,'2024-11-10','2024-12-25','Ahmed Khalid',            6,1800, 'High',    'Completed',  7,'Replace all piston packing sets on 3 pumps.')
ON CONFLICT (id) DO UPDATE SET
  asset_id=EXCLUDED.asset_id, task=EXCLUDED.task, type=EXCLUDED.type,
  freq=EXCLUDED.freq, last_done=EXCLUDED.last_done, next_due=EXCLUDED.next_due,
  tech=EXCLUDED.tech, hours=EXCLUDED.hours, cost=EXCLUDED.cost,
  priority=EXCLUDED.priority, status=EXCLUDED.status,
  alert_days=EXCLUDED.alert_days, notes=EXCLUDED.notes;

-- ─── MAINTENANCE LOGS ─────────────────────────────────────────────────────────
INSERT INTO maintenance_logs (schedule_id,completion_date,performed_by,hours,cost,parts_used,notes) VALUES
  ('PM-012','2024-12-14','Hughes Network Tech',2.5,1700,'None',             'Realigned dish 0.3° east. Signal improved 74%→91%.'),
  ('PM-014','2024-12-24','Ahmed Khalid',       7,  2100,'Garlock kits x18', 'All 3 pumps serviced. Hairline crack on pump #2 liner — replaced.')
ON CONFLICT DO NOTHING;

-- ─── TRANSFERS ────────────────────────────────────────────────────────────────
INSERT INTO transfers (id,asset_id,asset_name,current_loc,destination,dest_rig,dest_company,priority,type,requested_by,request_date,required_date,reason,instructions,status,ops_approved_by,ops_approved_date,ops_action,ops_comment,mgr_approved_by,mgr_approved_date,mgr_action,mgr_comment) VALUES
  ('TR-001','AST-001','Top Drive System','Ghawar Field','NABORS 1250-E – Permian Basin','NABORS 1250-E','NABORS Industries',
   'High','Rig to Rig','Sara Al-Rashid','2025-01-10','2025-01-25',
   'Top drive required for well P-44 spud at Permian Basin.',
   'Handle with crane only. Do not tilt >15°.',
   'Ops Approved','James Miller','2025-01-11','approve',
   'Approved. Coordinate with logistics.',NULL,NULL,NULL,NULL),
  ('TR-002','AST-004','Mud Pumps (3x)','Permian Basin','Workshop – Bay 4 (Overhaul)',NULL,NULL,
   'Critical','For Maintenance','Ahmad Mohammed','2025-01-08','2025-01-12',
   'Mud pumps require emergency overhaul. Liner wear detected on all 3 units.',
   'Transport on flatbed. Keep units upright. Drain fluid before transport.',
   'Completed','James Miller','2025-01-08','approve',
   'Critical – approved immediately.',
   'Sara Al-Rashid','2025-01-09','approve',
   'Approved. Schedule overhaul ASAP. Budget pre-approved.'),
  ('TR-003','AST-008','H2S Detection System','Permian Basin','Khafji Field – KJO Land Rig #3','KJO Land Rig #3','Al-Khafji Joint Operations',
   'Normal','Field to Field','David Chen','2025-01-15','2025-01-30',
   'H2S detection system requested by KJO site.',
   'Calibrate before transport. Include all sensor heads.',
   'Pending',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL)
ON CONFLICT (id) DO UPDATE SET
  asset_id=EXCLUDED.asset_id, asset_name=EXCLUDED.asset_name,
  status=EXCLUDED.status, priority=EXCLUDED.priority;

-- ─── USERS ────────────────────────────────────────────────────────────────────
INSERT INTO app_users (name,role,dept,email,color,initials,active) VALUES
  ('Ahmad Mohammed','Admin',        'Asset Management','a.mohammed@company.com','#0070F2','AM',true),
  ('Sara Al-Rashid','Asset Manager','Operations',      's.alrashid@company.com','#8B5CF6','SR',true),
  ('James Miller',  'Viewer',       'Finance',          'j.miller@company.com', '#107E3E','JM',true),
  ('Layla Hassan',  'Editor',       'Contracts',        'l.hassan@company.com', '#E9730C','LH',true),
  ('David Chen',    'Viewer',       'Engineering',      'd.chen@company.com',   '#BB0000','DC',true),
  ('Fatima Al-Zahra','Editor',      'Maintenance',      'f.alzahra@company.com','#0070F2','FZ',true)
ON CONFLICT (email) DO UPDATE SET
  name=EXCLUDED.name, role=EXCLUDED.role, dept=EXCLUDED.dept,
  color=EXCLUDED.color, initials=EXCLUDED.initials, active=EXCLUDED.active;

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────
INSERT INTO notifications (icon,kind,title,description,time_label,is_read) VALUES
  ('fas fa-exclamation-triangle','warning','Contract Expiry Warning', 'ADC Rig #7 contract expires in 15 days (Jan 14, 2025)','2 hours ago',false),
  ('fas fa-tools',               'warning','Maintenance Alert',        'Asset AST-004 (Mud Pumps) requires scheduled maintenance','4 hours ago',false),
  ('fas fa-file-import',         'info',   'Import Completed',         '12 assets imported successfully from Excel file',          'Yesterday',  false),
  ('fas fa-check-circle',        'success','Asset Activated',          'AST-009 (Rotary Table) has been activated',                '2 days ago', false),
  ('fas fa-envelope',            'info',   'Email Alert Sent',         'Maintenance report sent to 3 recipients',                  '3 days ago', true)
ON CONFLICT DO NOTHING;

-- ─── VERIFY ───────────────────────────────────────────────────────────────────
SELECT 'companies'             ,COUNT(*) FROM companies
UNION ALL SELECT 'rigs'        ,COUNT(*) FROM rigs
UNION ALL SELECT 'assets'      ,COUNT(*) FROM assets
UNION ALL SELECT 'contracts'   ,COUNT(*) FROM contracts
UNION ALL SELECT 'bom_items'   ,COUNT(*) FROM bom_items
UNION ALL SELECT 'certificates',COUNT(*) FROM certificates
UNION ALL SELECT 'maintenance' ,COUNT(*) FROM maintenance_schedules
UNION ALL SELECT 'transfers'   ,COUNT(*) FROM transfers
UNION ALL SELECT 'users'       ,COUNT(*) FROM app_users
UNION ALL SELECT 'notifications',COUNT(*) FROM notifications;
