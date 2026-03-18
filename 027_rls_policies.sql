-- ============================================================
--  027_rls_policies.sql
--
--  PURPOSE
--  -------
--  Enable RLS on the runtime tables used by the app and create
--  role-aware policies that match the restored schema.
--
--  NOTES
--  -----
--  * Uses maintenance_schedules (the real runtime table name)
--    instead of the removed maintenance table.
--  * Uses dynamic table / column checks so the migration can run
--    cleanly even when some optional tables are absent.
--  * Adds coverage for restored runtime tables: clients,
--    delete_requests, and push_subscriptions.
-- ============================================================

BEGIN;

-- ============================================================
--  STEP 1 — Helper functions for request claims
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_role()
RETURNS TEXT
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    current_setting('request.jwt.claims', true)::json->>'app_role',
    CASE
      WHEN current_setting('role', true) IN ('service_role', 'postgres', 'supabase_admin')
      THEN 'Admin'
      ELSE 'Viewer'
    END
  );
$$;

CREATE OR REPLACE FUNCTION public.app_user_id()
RETURNS TEXT
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT NULLIF(
    COALESCE(current_setting('request.jwt.claims', true)::json->>'sub', ''),
    ''
  );
$$;

CREATE OR REPLACE FUNCTION public.app_client_id()
RETURNS TEXT
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT NULLIF(
    COALESCE(
      current_setting('request.jwt.claims', true)::json->>'client_id',
      current_setting('request.jwt.claims', true)::json->'app_metadata'->>'client_id',
      ''
    ),
    ''
  );
$$;

GRANT EXECUTE ON FUNCTION public.app_role() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.app_user_id() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.app_client_id() TO anon, authenticated, service_role;

-- ============================================================
--  STEP 2 — ENABLE RLS on runtime tables that exist
-- ============================================================

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'rigs',
    'contracts',
    'assets',
    'bom_items',
    'maintenance_schedules',
    'maintenance_logs',
    'certificates',
    'transfers',
    'workshops',
    'inspections',
    'projects',
    'app_users',
    'notifications',
    'clients',
    'delete_requests',
    'push_subscriptions'
  ] LOOP
    IF to_regclass(format('public.%I', tbl)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);
    END IF;
  END LOOP;
END;
$$;

-- ============================================================
--  STEP 3 — DROP old policies on managed runtime tables
-- ============================================================

DO $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    SELECT p.tablename, p.policyname
    FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.tablename IN (
        'rigs',
        'contracts',
        'assets',
        'bom_items',
        'maintenance_schedules',
        'maintenance_logs',
        'certificates',
        'transfers',
        'workshops',
        'inspections',
        'projects',
        'app_users',
        'notifications',
        'clients',
        'delete_requests',
        'push_subscriptions'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', rec.policyname, rec.tablename);
  END LOOP;
END;
$$;

-- ============================================================
--  STEP 4 — GRANT table privileges required for RLS evaluation
-- ============================================================

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'rigs',
    'contracts',
    'assets',
    'bom_items',
    'maintenance_schedules',
    'maintenance_logs',
    'certificates',
    'transfers',
    'workshops',
    'inspections',
    'projects',
    'app_users',
    'notifications',
    'clients',
    'delete_requests',
    'push_subscriptions'
  ] LOOP
    IF to_regclass(format('public.%I', tbl)) IS NOT NULL THEN
      EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO anon, authenticated', tbl);
    END IF;
  END LOOP;
END;
$$;

-- ============================================================
--  STEP 5 — Core role matrix policies for tables that remain
--           broadly readable with role-based writes
-- ============================================================

DO $$
DECLARE
  rec RECORD;
  sql TEXT;
BEGIN
  FOR rec IN
    SELECT *
    FROM (
      VALUES
        ('rigs', 'rigs_select', 'SELECT', 'true', NULL),
        ('rigs', 'rigs_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager')$expr$),
        ('rigs', 'rigs_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager')$expr$, $expr$public.app_role() IN ('Admin','Manager')$expr$),
        ('rigs', 'rigs_delete', 'DELETE', $expr$public.app_role() = 'Admin'$expr$, NULL),

        ('contracts', 'contracts_select', 'SELECT', 'true', NULL),
        ('contracts', 'contracts_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager')$expr$),
        ('contracts', 'contracts_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager')$expr$, $expr$public.app_role() IN ('Admin','Manager')$expr$),
        ('contracts', 'contracts_delete', 'DELETE', $expr$public.app_role() = 'Admin'$expr$, NULL),

        ('assets', 'assets_select', 'SELECT', 'true', NULL),
        ('assets', 'assets_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('assets', 'assets_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('assets', 'assets_delete', 'DELETE', $expr$public.app_role() = 'Admin'$expr$, NULL),

        ('bom_items', 'bom_items_select', 'SELECT', 'true', NULL),
        ('bom_items', 'bom_items_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('bom_items', 'bom_items_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('bom_items', 'bom_items_delete', 'DELETE', $expr$public.app_role() IN ('Admin','Manager')$expr$, NULL),

        ('maintenance_schedules', 'maintenance_schedules_select', 'SELECT', 'true', NULL),
        ('maintenance_schedules', 'maintenance_schedules_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$),
        ('maintenance_schedules', 'maintenance_schedules_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$),
        ('maintenance_schedules', 'maintenance_schedules_delete', 'DELETE', $expr$public.app_role() IN ('Admin','Manager')$expr$, NULL),

        ('maintenance_logs', 'maintenance_logs_select', 'SELECT', 'true', NULL),
        ('maintenance_logs', 'maintenance_logs_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$),
        ('maintenance_logs', 'maintenance_logs_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$),
        ('maintenance_logs', 'maintenance_logs_delete', 'DELETE', $expr$public.app_role() IN ('Admin','Manager')$expr$, NULL),

        ('certificates', 'certificates_select', 'SELECT', 'true', NULL),
        ('certificates', 'certificates_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('certificates', 'certificates_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('certificates', 'certificates_delete', 'DELETE', $expr$public.app_role() IN ('Admin','Manager')$expr$, NULL),

        ('transfers', 'transfers_select', 'SELECT', 'true', NULL),
        ('transfers', 'transfers_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('transfers', 'transfers_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('transfers', 'transfers_delete', 'DELETE', $expr$public.app_role() = 'Admin'$expr$, NULL),

        ('workshops', 'workshops_select', 'SELECT', 'true', NULL),
        ('workshops', 'workshops_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$),
        ('workshops', 'workshops_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor','Technician')$expr$),
        ('workshops', 'workshops_delete', 'DELETE', $expr$public.app_role() IN ('Admin','Manager')$expr$, NULL),

        ('inspections', 'inspections_select', 'SELECT', 'true', NULL),
        ('inspections', 'inspections_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('inspections', 'inspections_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('inspections', 'inspections_delete', 'DELETE', $expr$public.app_role() IN ('Admin','Manager')$expr$, NULL),

        ('projects', 'projects_select', 'SELECT', 'true', NULL),
        ('projects', 'projects_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('projects', 'projects_update', 'UPDATE', $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('projects', 'projects_delete', 'DELETE', $expr$public.app_role() IN ('Admin','Manager')$expr$, NULL),

        ('notifications', 'notifications_select', 'SELECT', 'true', NULL),
        ('notifications', 'notifications_insert', 'INSERT', NULL, $expr$public.app_role() IN ('Admin','Manager','Supervisor')$expr$),
        ('notifications', 'notifications_update', 'UPDATE', 'true', 'true'),
        ('notifications', 'notifications_delete', 'DELETE', $expr$public.app_role() = 'Admin'$expr$, NULL)
    ) AS t(table_name, policy_name, command_name, using_expr, check_expr)
  LOOP
    IF to_regclass(format('public.%I', rec.table_name)) IS NULL THEN
      CONTINUE;
    END IF;

    sql := format(
      'CREATE POLICY %I ON public.%I FOR %s',
      rec.policy_name,
      rec.table_name,
      rec.command_name
    );

    IF rec.using_expr IS NOT NULL THEN
      sql := sql || format(' USING (%s)', rec.using_expr);
    END IF;

    IF rec.check_expr IS NOT NULL THEN
      sql := sql || format(' WITH CHECK (%s)', rec.check_expr);
    END IF;

    EXECUTE sql;
  END LOOP;
END;
$$;

-- ============================================================
--  STEP 6 — app_users policies
-- ============================================================

DO $$
BEGIN
  IF to_regclass('public.app_users') IS NOT NULL THEN
    EXECUTE 'CREATE POLICY app_users_select_admin ON public.app_users FOR SELECT USING (public.app_role() IN (''Admin'',''Manager''))';

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'app_users'
        AND column_name = 'id'
    ) THEN
      EXECUTE 'CREATE POLICY app_users_select_self ON public.app_users FOR SELECT USING (id::text = public.app_user_id())';
    END IF;

    EXECUTE 'CREATE POLICY app_users_insert_admin ON public.app_users FOR INSERT WITH CHECK (public.app_role() = ''Admin'')';
    EXECUTE 'CREATE POLICY app_users_update_admin ON public.app_users FOR UPDATE USING (public.app_role() = ''Admin'') WITH CHECK (public.app_role() = ''Admin'')';
    EXECUTE 'CREATE POLICY app_users_delete_admin ON public.app_users FOR DELETE USING (public.app_role() = ''Admin'')';
  END IF;
END;
$$;

-- ============================================================
--  STEP 7 — clients policies
-- ============================================================

DO $$
BEGIN
  IF to_regclass('public.clients') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'clients'
        AND column_name = 'id'
    ) THEN
      EXECUTE 'CREATE POLICY clients_select ON public.clients FOR SELECT USING (public.app_role() = ''Admin'' OR id::text = public.app_client_id())';
    ELSE
      EXECUTE 'CREATE POLICY clients_select ON public.clients FOR SELECT USING (public.app_role() = ''Admin'')';
    END IF;

    EXECUTE 'CREATE POLICY clients_insert ON public.clients FOR INSERT WITH CHECK (public.app_role() = ''Admin'')';
    EXECUTE 'CREATE POLICY clients_update ON public.clients FOR UPDATE USING (public.app_role() = ''Admin'') WITH CHECK (public.app_role() = ''Admin'')';
    EXECUTE 'CREATE POLICY clients_delete ON public.clients FOR DELETE USING (public.app_role() = ''Admin'')';
  END IF;
END;
$$;

-- ============================================================
--  STEP 8 — delete_requests policies
-- ============================================================

DO $$
DECLARE
  manager_check TEXT := $expr$public.app_role() IN ('Admin','Manager','Superintendent','Drilling Manager','Asset Manager','Maintenance Manager','Project Manager')$expr$;
BEGIN
  IF to_regclass('public.delete_requests') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'delete_requests'
        AND column_name = 'requested_by_user_id'
    ) THEN
      EXECUTE format(
        'CREATE POLICY delete_requests_select ON public.delete_requests FOR SELECT USING (%s OR requested_by_user_id::text = public.app_user_id())',
        manager_check
      );
      EXECUTE format(
        'CREATE POLICY delete_requests_insert ON public.delete_requests FOR INSERT WITH CHECK (%s OR requested_by_user_id::text = public.app_user_id())',
        manager_check
      );
    ELSE
      EXECUTE format(
        'CREATE POLICY delete_requests_select ON public.delete_requests FOR SELECT USING (%s)',
        manager_check
      );
      EXECUTE format(
        'CREATE POLICY delete_requests_insert ON public.delete_requests FOR INSERT WITH CHECK (%s)',
        manager_check
      );
    END IF;

    EXECUTE format(
      'CREATE POLICY delete_requests_update ON public.delete_requests FOR UPDATE USING (%s) WITH CHECK (%s)',
      manager_check,
      manager_check
    );
    EXECUTE 'CREATE POLICY delete_requests_delete ON public.delete_requests FOR DELETE USING (public.app_role() = ''Admin'')';
  END IF;
END;
$$;

-- ============================================================
--  STEP 9 — push_subscriptions policies
-- ============================================================

DO $$
BEGIN
  IF to_regclass('public.push_subscriptions') IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'push_subscriptions'
        AND column_name = 'user_id'
    ) THEN
      EXECUTE 'CREATE POLICY push_subscriptions_select ON public.push_subscriptions FOR SELECT USING (public.app_role() = ''Admin'' OR user_id::text = public.app_user_id())';
      EXECUTE 'CREATE POLICY push_subscriptions_insert ON public.push_subscriptions FOR INSERT WITH CHECK (public.app_role() = ''Admin'' OR user_id::text = public.app_user_id())';
      EXECUTE 'CREATE POLICY push_subscriptions_update ON public.push_subscriptions FOR UPDATE USING (public.app_role() = ''Admin'' OR user_id::text = public.app_user_id()) WITH CHECK (public.app_role() = ''Admin'' OR user_id::text = public.app_user_id())';
      EXECUTE 'CREATE POLICY push_subscriptions_delete ON public.push_subscriptions FOR DELETE USING (public.app_role() = ''Admin'' OR user_id::text = public.app_user_id())';
    ELSE
      EXECUTE 'CREATE POLICY push_subscriptions_select ON public.push_subscriptions FOR SELECT USING (public.app_role() = ''Admin'')';
      EXECUTE 'CREATE POLICY push_subscriptions_insert ON public.push_subscriptions FOR INSERT WITH CHECK (public.app_role() = ''Admin'')';
      EXECUTE 'CREATE POLICY push_subscriptions_update ON public.push_subscriptions FOR UPDATE USING (public.app_role() = ''Admin'') WITH CHECK (public.app_role() = ''Admin'')';
      EXECUTE 'CREATE POLICY push_subscriptions_delete ON public.push_subscriptions FOR DELETE USING (public.app_role() = ''Admin'')';
    END IF;
  END IF;
END;
$$;

-- ============================================================
--  STEP 10 — Verification query
-- ============================================================

SELECT
  tablename,
  policyname,
  cmd AS operation,
  qual AS using_expr,
  with_check AS with_check_expr
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'rigs',
    'contracts',
    'assets',
    'bom_items',
    'maintenance_schedules',
    'maintenance_logs',
    'certificates',
    'transfers',
    'workshops',
    'inspections',
    'projects',
    'app_users',
    'notifications',
    'clients',
    'delete_requests',
    'push_subscriptions'
  )
ORDER BY tablename, cmd, policyname;

COMMIT;
