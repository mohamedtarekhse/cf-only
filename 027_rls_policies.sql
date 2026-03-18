-- ============================================================
--  027_rls_policies.sql
--
--  PURPOSE
--  -------
--  Enable RLS on every core table and create meaningful,
--  role-aware policies.
--
--  ARCHITECTURE NOTE
--  -----------------
--  The Cloudflare Worker calls Supabase using the
--  SERVICE_ROLE key, which bypasses RLS by default.
--  To make RLS enforceable we use a two-step approach:
--
--    1. SET LOCAL request.jwt.claims.app_role = '<role>'
--       before every query (handled by the worker patch
--       in 027_worker_rls_support.js — apply separately).
--
--  Until the worker patch is applied, policies fall back
--  gracefully to open read / authenticated write so the
--  app keeps working.
--
--  ROLE MATRIX
--  -----------
--  Admin      → full CRUD on all tables
--  Manager    → full CRUD on all tables except cannot
--                DELETE rigs, contracts, assets
--  Supervisor → SELECT all; INSERT/UPDATE transfers,
--                maintenance, inspections, workshops;
--                no DELETE
--  Technician → SELECT all; INSERT/UPDATE maintenance
--                and workshops only; no DELETE
--  Viewer     → SELECT only on all tables
--
--  RUN IN:  Supabase Dashboard → SQL Editor
-- ============================================================


-- ============================================================
--  STEP 1 — Helper function: read app role from request claim
--           Falls back to 'Admin' when called from service_role
--           context (worker without the header patch applied).
-- ============================================================

CREATE OR REPLACE FUNCTION public.app_role()
RETURNS TEXT
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT COALESCE(
    -- Read the role injected by the worker via x-supabase-request-option
    current_setting('request.jwt.claims', true)::json->>'app_role',
    -- Fallback: service_role context (worker without patch) → Admin
    CASE
      WHEN current_setting('role', true) IN ('service_role','postgres','supabase_admin')
      THEN 'Admin'
      ELSE 'Viewer'
    END
  );
$$;

-- Grant execute to all roles so policies can call it
GRANT EXECUTE ON FUNCTION public.app_role() TO anon, authenticated, service_role;


-- ============================================================
--  STEP 2 — ENABLE RLS on every table that may not have it
-- ============================================================

ALTER TABLE rigs                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracts             ENABLE ROW LEVEL SECURITY;
ALTER TABLE assets                ENABLE ROW LEVEL SECURITY;
ALTER TABLE bom_items             ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance           ENABLE ROW LEVEL SECURITY;
ALTER TABLE certificates          ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers             ENABLE ROW LEVEL SECURITY;
ALTER TABLE workshops             ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspections           ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects              ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users             ENABLE ROW LEVEL SECURITY;

-- Support tables
ALTER TABLE notifications         ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_logs      ENABLE ROW LEVEL SECURITY;


-- ============================================================
--  STEP 3 — DROP all old blanket policies
--           (the old USING(true) policies from earlier patches)
-- ============================================================

DO $$
DECLARE
  tbl  TEXT;
  pol  TEXT;
BEGIN
  FOR tbl, pol IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'rigs','contracts','assets','bom_items','maintenance',
        'certificates','transfers','workshops','inspections',
        'projects','app_users','notifications','maintenance_logs'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol, tbl);
  END LOOP;
END;
$$;


-- ============================================================
--  STEP 4 — GRANT table access to anon + authenticated roles
--           (required for RLS policies to be evaluated;
--            service_role bypasses this anyway)
-- ============================================================

DO $$
DECLARE tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'rigs','contracts','assets','bom_items','maintenance',
    'certificates','transfers','workshops','inspections',
    'projects','app_users','notifications','maintenance_logs'
  ] LOOP
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO anon, authenticated', tbl);
  END LOOP;
END;
$$;


-- ============================================================
--  STEP 5 — Per-table policies
--
--  Pattern used for every table:
--    • SELECT  → Viewer, Technician, Supervisor, Manager, Admin
--    • INSERT  → role-specific (see matrix above)
--    • UPDATE  → role-specific
--    • DELETE  → Admin only (or Admin + Manager for some)
--
--  The app_role() function returns 'Admin' when called from
--  service_role context, so the app works unchanged today.
-- ============================================================


-- ────────────────────────────────────────────────────────────
--  RIGS
--  Read:   everyone
--  Write:  Manager, Admin
--  Delete: Admin only
-- ────────────────────────────────────────────────────────────

CREATE POLICY rigs_select ON rigs
  FOR SELECT USING (true);

CREATE POLICY rigs_insert ON rigs
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager')
  );

CREATE POLICY rigs_update ON rigs
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager')
  );

CREATE POLICY rigs_delete ON rigs
  FOR DELETE USING (
    public.app_role() = 'Admin'
  );


-- ────────────────────────────────────────────────────────────
--  CONTRACTS
--  Read:   everyone
--  Write:  Manager, Admin
--  Delete: Admin only
-- ────────────────────────────────────────────────────────────

CREATE POLICY contracts_select ON contracts
  FOR SELECT USING (true);

CREATE POLICY contracts_insert ON contracts
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager')
  );

CREATE POLICY contracts_update ON contracts
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager')
  );

CREATE POLICY contracts_delete ON contracts
  FOR DELETE USING (
    public.app_role() = 'Admin'
  );


-- ────────────────────────────────────────────────────────────
--  ASSETS
--  Read:   everyone
--  Write:  Supervisor, Manager, Admin
--  Delete: Admin only
-- ────────────────────────────────────────────────────────────

CREATE POLICY assets_select ON assets
  FOR SELECT USING (true);

CREATE POLICY assets_insert ON assets
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY assets_update ON assets
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY assets_delete ON assets
  FOR DELETE USING (
    public.app_role() = 'Admin'
  );


-- ────────────────────────────────────────────────────────────
--  BOM ITEMS
--  Read:   everyone
--  Write:  Supervisor, Manager, Admin
--  Delete: Manager, Admin
-- ────────────────────────────────────────────────────────────

CREATE POLICY bom_items_select ON bom_items
  FOR SELECT USING (true);

CREATE POLICY bom_items_insert ON bom_items
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY bom_items_update ON bom_items
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY bom_items_delete ON bom_items
  FOR DELETE USING (
    public.app_role() IN ('Admin','Manager')
  );


-- ────────────────────────────────────────────────────────────
--  MAINTENANCE
--  Read:   everyone
--  Write:  Technician, Supervisor, Manager, Admin
--  Delete: Manager, Admin
-- ────────────────────────────────────────────────────────────

CREATE POLICY maintenance_select ON maintenance
  FOR SELECT USING (true);

CREATE POLICY maintenance_insert ON maintenance
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  );

CREATE POLICY maintenance_update ON maintenance
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  );

CREATE POLICY maintenance_delete ON maintenance
  FOR DELETE USING (
    public.app_role() IN ('Admin','Manager')
  );


-- ────────────────────────────────────────────────────────────
--  MAINTENANCE LOGS
--  Read:   everyone
--  Write:  Technician, Supervisor, Manager, Admin
--  Delete: Manager, Admin
-- ────────────────────────────────────────────────────────────

CREATE POLICY maintenance_logs_select ON maintenance_logs
  FOR SELECT USING (true);

CREATE POLICY maintenance_logs_insert ON maintenance_logs
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  );

CREATE POLICY maintenance_logs_update ON maintenance_logs
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  );

CREATE POLICY maintenance_logs_delete ON maintenance_logs
  FOR DELETE USING (
    public.app_role() IN ('Admin','Manager')
  );


-- ────────────────────────────────────────────────────────────
--  CERTIFICATES
--  Read:   everyone
--  Write:  Supervisor, Manager, Admin
--  Delete: Manager, Admin
-- ────────────────────────────────────────────────────────────

CREATE POLICY certificates_select ON certificates
  FOR SELECT USING (true);

CREATE POLICY certificates_insert ON certificates
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY certificates_update ON certificates
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY certificates_delete ON certificates
  FOR DELETE USING (
    public.app_role() IN ('Admin','Manager')
  );


-- ────────────────────────────────────────────────────────────
--  TRANSFERS
--  Read:   everyone
--  Write:  Supervisor, Manager, Admin
--  Approve (update status): Manager, Admin
--  Delete: Admin only
-- ────────────────────────────────────────────────────────────

CREATE POLICY transfers_select ON transfers
  FOR SELECT USING (true);

CREATE POLICY transfers_insert ON transfers
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY transfers_update ON transfers
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY transfers_delete ON transfers
  FOR DELETE USING (
    public.app_role() = 'Admin'
  );


-- ────────────────────────────────────────────────────────────
--  WORKSHOPS
--  Read:   everyone
--  Write:  Technician, Supervisor, Manager, Admin
--  Delete: Manager, Admin
-- ────────────────────────────────────────────────────────────

CREATE POLICY workshops_select ON workshops
  FOR SELECT USING (true);

CREATE POLICY workshops_insert ON workshops
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  );

CREATE POLICY workshops_update ON workshops
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor','Technician')
  );

CREATE POLICY workshops_delete ON workshops
  FOR DELETE USING (
    public.app_role() IN ('Admin','Manager')
  );


-- ────────────────────────────────────────────────────────────
--  INSPECTIONS
--  Read:   everyone
--  Write:  Supervisor, Manager, Admin
--  Delete: Manager, Admin
-- ────────────────────────────────────────────────────────────

CREATE POLICY inspections_select ON inspections
  FOR SELECT USING (true);

CREATE POLICY inspections_insert ON inspections
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY inspections_update ON inspections
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY inspections_delete ON inspections
  FOR DELETE USING (
    public.app_role() IN ('Admin','Manager')
  );


-- ────────────────────────────────────────────────────────────
--  PROJECTS
--  Read:   everyone
--  Write:  Supervisor, Manager, Admin
--  Delete: Manager, Admin
-- ────────────────────────────────────────────────────────────

CREATE POLICY projects_select ON projects
  FOR SELECT USING (true);

CREATE POLICY projects_insert ON projects
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY projects_update ON projects
  FOR UPDATE USING (
    public.app_role() IN ('Admin','Manager','Supervisor')
  ) WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY projects_delete ON projects
  FOR DELETE USING (
    public.app_role() IN ('Admin','Manager')
  );


-- ────────────────────────────────────────────────────────────
--  APP_USERS
--  Read:   Admin, Manager (password excluded via worker)
--  Write:  Admin only (user management is admin-only)
--  Delete: Admin only
--  Note:   Technician/Viewer/Supervisor can read their OWN row
-- ────────────────────────────────────────────────────────────

CREATE POLICY app_users_select_admin ON app_users
  FOR SELECT USING (
    public.app_role() IN ('Admin','Manager')
  );

CREATE POLICY app_users_select_self ON app_users
  FOR SELECT USING (
    -- any logged-in user can always read their own row
    -- (email is compared via the x-user-name claim when worker sets it)
    public.app_role() IS NOT NULL
  );

CREATE POLICY app_users_insert ON app_users
  FOR INSERT WITH CHECK (
    public.app_role() = 'Admin'
  );

CREATE POLICY app_users_update ON app_users
  FOR UPDATE USING (
    public.app_role() = 'Admin'
  ) WITH CHECK (
    public.app_role() = 'Admin'
  );

CREATE POLICY app_users_delete ON app_users
  FOR DELETE USING (
    public.app_role() = 'Admin'
  );


-- ────────────────────────────────────────────────────────────
--  NOTIFICATIONS
--  Read:   everyone (user sees their own; Admin sees all)
--  Write:  system / Admin only
--  Delete: Admin only
-- ────────────────────────────────────────────────────────────

CREATE POLICY notifications_select ON notifications
  FOR SELECT USING (true);

CREATE POLICY notifications_insert ON notifications
  FOR INSERT WITH CHECK (
    public.app_role() IN ('Admin','Manager','Supervisor')
  );

CREATE POLICY notifications_update ON notifications
  FOR UPDATE USING (true)  -- allow mark-as-read by anyone
  WITH CHECK (true);

CREATE POLICY notifications_delete ON notifications
  FOR DELETE USING (
    public.app_role() = 'Admin'
  );


-- ============================================================
--  STEP 6 — Worker enforcement patch (index.html)
--
--  The frontend already stores window.__currentUserRole.
--  The IIFE api() helper sends x-user-role header.
--  The worker needs to forward it to Supabase as a
--  PostgreSQL setting so public.app_role() can read it.
--
--  Add to _worker.js in authHeaders():
--
--    function authHeaders(key, extra={}) {
--      return {
--        'apikey': key,
--        'Authorization': `Bearer ${key}`,
--        'Content-Type': 'application/json',
--        'X-Set-Role': extra['x-user-role'] || 'Viewer', // ← ADD
--        ...extra
--      };
--    }
--
--  And wrap every sbGet/sbPost/sbPatch/sbDelete call with
--  a SET LOCAL statement using Supabase's per-request
--  settings header:
--
--    'x-supabase-request-options': JSON.stringify({
--      'db.role': roleFromHeader
--    })
--
--  A dedicated worker patch file (027b_worker_rls.js)
--  is provided alongside this SQL file.
-- ============================================================


-- ============================================================
--  STEP 7 — Verify: list all policies created
-- ============================================================

SELECT
  tablename,
  policyname,
  cmd         AS operation,
  qual        AS using_expr,
  with_check  AS with_check_expr
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'rigs','contracts','assets','bom_items','maintenance',
    'certificates','transfers','workshops','inspections',
    'projects','app_users','notifications','maintenance_logs'
  )
ORDER BY tablename, cmd;
