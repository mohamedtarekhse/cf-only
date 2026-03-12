-- 031_post_migration_verification.sql
-- Run AFTER: 030_safe_non_breaking_migration.sql
-- Read-only verification bundle (no DML/DDL).
-- Output shape is stable per check row: check_name, status, details

WITH
required_tables(table_name) AS (
  VALUES
    ('assets'),
    ('maintenance_schedules'),
    ('maintenance_logs'),
    ('transfers'),
    ('certificates'),
    ('bom_items'),
    ('contracts'),
    ('rigs'),
    ('projects'),
    ('workshops'),
    ('app_users'),
    ('notifications'),
    ('reg_bop'),
    ('reg_well_head'),
    ('reg_well_control'),
    ('reg_fire_extinguishers'),
    ('reg_scba')
),
required_columns(table_name, column_name) AS (
  VALUES
    -- assets
    ('assets','asset_id'),('assets','name'),('assets','status'),('assets','rig_name'),('assets','location'),

    -- maintenance schedules + logs
    ('maintenance_schedules','id'),('maintenance_schedules','asset_id'),('maintenance_schedules','task'),
    ('maintenance_schedules','freq'),('maintenance_schedules','tech'),('maintenance_schedules','alert_days'),
    ('maintenance_schedules','next_due'),('maintenance_schedules','status'),('maintenance_schedules','last_done'),
    ('maintenance_logs','schedule_id'),('maintenance_logs','completion_date'),('maintenance_logs','performed_by'),

    -- transfers approval flow
    ('transfers','id'),('transfers','asset_id'),('transfers','destination'),('transfers','dest_rig'),('transfers','status'),
    ('transfers','supt_approved_by'),('transfers','supt_action'),
    ('transfers','ops_approved_by'),('transfers','ops_action'),
    ('transfers','mgr_approved_by'),('transfers','mgr_action'),

    -- certificates
    ('certificates','cert_id'),('certificates','asset_id'),('certificates','inspection_type'),('certificates','next_inspection'),

    -- contracts
    ('contracts','id'),('contracts','rig'),('contracts','start_date'),('contracts','end_date'),('contracts','status'),

    -- workshops
    ('workshops','workshop_id'),('workshops','workshop_name'),('workshops','assigned_rig'),('workshops','status'),

    -- users + notifications
    ('app_users','id'),('app_users','name'),('app_users','role'),('app_users','email'),('app_users','active'),
    ('notifications','id'),('notifications','is_read'),('notifications','created_at')
),
required_indexes(index_name) AS (
  VALUES
    ('idx_assets_asset_id'),
    ('idx_assets_rig_name'),
    ('idx_assets_status'),
    ('idx_bom_items_asset_id'),
    ('idx_certificates_asset_id'),
    ('idx_maint_sched_asset_id'),
    ('idx_maint_sched_next_due'),
    ('idx_maint_logs_schedule_id'),
    ('idx_transfers_asset_id'),
    ('idx_transfers_status'),
    ('idx_projects_project_id'),
    ('idx_workshops_workshop_id'),
    ('idx_notifications_is_read'),
    ('idx_contract_assets_contract_id'),
    ('idx_contract_assets_asset_id')
),
checks AS (
  -- ============================================================
  -- Schema presence checks
  -- ============================================================
  SELECT
    'schema.table.' || t.table_name AS check_name,
    CASE WHEN EXISTS (
      SELECT 1
      FROM information_schema.tables it
      WHERE it.table_schema = 'public' AND it.table_name = t.table_name
    ) THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE WHEN EXISTS (
      SELECT 1
      FROM information_schema.tables it
      WHERE it.table_schema = 'public' AND it.table_name = t.table_name
    )
    THEN 'Table exists.'
    ELSE 'Missing table. Run 030_safe_non_breaking_migration.sql (and re-run this check).'
    END AS details
  FROM required_tables t

  UNION ALL

  -- ============================================================
  -- Column contract checks
  -- ============================================================
  SELECT
    'schema.column.' || c.table_name || '.' || c.column_name AS check_name,
    CASE WHEN EXISTS (
      SELECT 1
      FROM information_schema.columns ic
      WHERE ic.table_schema = 'public'
        AND ic.table_name = c.table_name
        AND ic.column_name = c.column_name
    ) THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE WHEN EXISTS (
      SELECT 1
      FROM information_schema.columns ic
      WHERE ic.table_schema = 'public'
        AND ic.table_name = c.table_name
        AND ic.column_name = c.column_name
    )
    THEN 'Column exists.'
    ELSE 'Missing required API/UI contract column. Apply migration 030 and verify schema drift fixes.'
    END AS details
  FROM required_columns c

  UNION ALL

  -- ============================================================
  -- Index checks
  -- ============================================================
  SELECT
    'schema.index.' || i.index_name AS check_name,
    CASE WHEN EXISTS (
      SELECT 1 FROM pg_indexes pi
      WHERE pi.schemaname = 'public' AND pi.indexname = i.index_name
    ) THEN 'PASS' ELSE 'WARN' END AS status,
    CASE WHEN EXISTS (
      SELECT 1 FROM pg_indexes pi
      WHERE pi.schemaname = 'public' AND pi.indexname = i.index_name
    )
    THEN 'Index exists.'
    ELSE 'Missing expected index (performance risk, not immediate functional break). Consider re-running 030.'
    END AS details
  FROM required_indexes i

  UNION ALL

  -- ============================================================
  -- Constraint checks (including NOT VALID state reporting)
  -- ============================================================
  SELECT
    'constraint.maintenance_schedules_status_chk' AS check_name,
    CASE
      WHEN c.oid IS NULL THEN 'WARN'
      WHEN c.convalidated THEN 'PASS'
      ELSE 'WARN'
    END AS status,
    CASE
      WHEN c.oid IS NULL THEN 'Constraint missing. Status values may drift; re-run 030 migration.'
      WHEN c.convalidated THEN 'Constraint present and validated.'
      ELSE 'Constraint present but NOT VALID. Existing rows may include legacy values; consider VALIDATE CONSTRAINT during maintenance window.'
    END AS details
  FROM (
    SELECT con.oid, con.convalidated
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace ns ON ns.oid = rel.relnamespace
    WHERE ns.nspname = 'public'
      AND rel.relname = 'maintenance_schedules'
      AND con.conname = 'maintenance_schedules_status_chk'
    LIMIT 1
  ) c
  RIGHT JOIN (SELECT 1) one ON TRUE

  UNION ALL

  -- ============================================================
  -- Legacy compatibility checks
  -- ============================================================
  SELECT
    'compat.maintenance.freq_populated' AS check_name,
    CASE
      WHEN COALESCE(s.total_rows,0) = 0 THEN 'WARN'
      WHEN COALESCE(s.null_freq_rows,0) = 0 THEN 'PASS'
      ELSE 'FAIL'
    END AS status,
    CASE
      WHEN COALESCE(s.total_rows,0) = 0 THEN 'No maintenance_schedules rows found; seed/import data if expected.'
      WHEN COALESCE(s.null_freq_rows,0) = 0 THEN 'All maintenance schedule rows have freq populated.'
      ELSE 'Found ' || s.null_freq_rows || ' row(s) with NULL freq. Backfill freq before using maintenance completion scheduling.'
    END AS details
  FROM (
    SELECT
      COUNT(*)::INT AS total_rows,
      COUNT(*) FILTER (WHERE freq IS NULL)::INT AS null_freq_rows
    FROM maintenance_schedules
  ) s

  UNION ALL

  SELECT
    'compat.maintenance.status_normalized' AS check_name,
    CASE
      WHEN COALESCE(s.invalid_status_rows,0) = 0 THEN 'PASS'
      ELSE 'WARN'
    END AS status,
    CASE
      WHEN COALESCE(s.invalid_status_rows,0) = 0 THEN 'No unexpected maintenance statuses found.'
      ELSE 'Found ' || s.invalid_status_rows || ' row(s) with non-standard status values. Worker normalizes some values, but cleanup is recommended.'
    END AS details
  FROM (
    SELECT COUNT(*) FILTER (
      WHERE status IS NOT NULL
        AND status NOT IN ('Scheduled','In Progress','Completed','Cancelled','Overdue','Due Soon')
    )::INT AS invalid_status_rows
    FROM maintenance_schedules
  ) s

  UNION ALL

  SELECT
    'compat.maintenance_logs.orphans' AS check_name,
    CASE
      WHEN COALESCE(o.orphan_logs,0) = 0 THEN 'PASS'
      ELSE 'WARN'
    END AS status,
    CASE
      WHEN COALESCE(o.orphan_logs,0) = 0 THEN 'No orphan maintenance logs detected.'
      ELSE 'Found ' || o.orphan_logs || ' orphan maintenance_logs rows (schedule_id not found). Investigate data integrity.'
    END AS details
  FROM (
    SELECT COUNT(*)::INT AS orphan_logs
    FROM maintenance_logs ml
    LEFT JOIN maintenance_schedules ms ON ms.id = ml.schedule_id
    WHERE ml.schedule_id IS NOT NULL AND ms.id IS NULL
  ) o

  UNION ALL

  SELECT
    'compat.legacy_table.maintenance_backfill_signal' AS check_name,
    CASE
      WHEN to_regclass('public.maintenance') IS NULL THEN 'PASS'
      WHEN legacy_rows > 0 AND schedule_rows = 0 THEN 'WARN'
      ELSE 'PASS'
    END AS status,
    CASE
      WHEN to_regclass('public.maintenance') IS NULL THEN 'Legacy maintenance table not present; no legacy backfill needed.'
      WHEN legacy_rows > 0 AND schedule_rows = 0 THEN 'Legacy maintenance has data but maintenance_schedules is empty. Verify migration backfill section in 030.'
      ELSE 'Legacy maintenance compatibility looks acceptable.'
    END AS details
  FROM (
    SELECT
      CASE WHEN to_regclass('public.maintenance') IS NULL THEN 0 ELSE (SELECT COUNT(*)::INT FROM maintenance) END AS legacy_rows,
      (SELECT COUNT(*)::INT FROM maintenance_schedules) AS schedule_rows
  ) l
)
SELECT check_name, status, details
FROM checks
ORDER BY
  CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END,
  check_name;

-- Summary (stable output shape)
WITH
required_tables(table_name) AS (
  VALUES
    ('assets'),('maintenance_schedules'),('maintenance_logs'),('transfers'),('certificates'),('bom_items'),
    ('contracts'),('rigs'),('projects'),('workshops'),('app_users'),('notifications'),
    ('reg_bop'),('reg_well_head'),('reg_well_control'),('reg_fire_extinguishers'),('reg_scba')
),
checks AS (
  SELECT
    CASE WHEN EXISTS (
      SELECT 1 FROM information_schema.tables t
      WHERE t.table_schema='public' AND t.table_name=rt.table_name
    ) THEN 'PASS' ELSE 'FAIL' END AS status
  FROM required_tables rt
  UNION ALL
  SELECT CASE WHEN EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema='public' AND c.table_name='maintenance_schedules' AND c.column_name='freq'
    ) THEN 'PASS' ELSE 'FAIL' END
  UNION ALL
  SELECT CASE WHEN EXISTS (
      SELECT 1 FROM pg_indexes i
      WHERE i.schemaname='public' AND i.indexname='idx_maint_sched_next_due'
    ) THEN 'PASS' ELSE 'WARN' END
  UNION ALL
  SELECT CASE WHEN EXISTS (
      SELECT 1 FROM pg_constraint con
      JOIN pg_class rel ON rel.oid=con.conrelid
      JOIN pg_namespace ns ON ns.oid=rel.relnamespace
      WHERE ns.nspname='public' AND rel.relname='maintenance_schedules' AND con.conname='maintenance_schedules_status_chk'
    ) THEN 'PASS' ELSE 'WARN' END
)
SELECT
  'summary.status.' || status AS check_name,
  status,
  'Total checks in this summary bucket: ' || COUNT(*)::TEXT AS details
FROM checks
GROUP BY status
ORDER BY CASE status WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END;
