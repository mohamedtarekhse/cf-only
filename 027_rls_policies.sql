-- 027_rls_policies.sql
-- Canonical application roles must match the Worker role vocabulary exactly.
-- Authoritative list (from `_worker.js`):
--   Admin
--   Manager
--   Superintendent
--   Drilling Manager
--   Asset Manager
--   Maintenance Manager
--   Project Manager
--   Engineer
--   Assistant
--   Viewer
--
-- Legacy aliases are normalized before policy checks so older rows/tokens still work:
--   Supervisor -> Superintendent
--   Technician -> Assistant
--   Editor -> Engineer

create or replace function public.app_role()
returns text
language sql
stable
as $$
  with raw_claims as (
    select nullif(current_setting('request.jwt.claims', true), '')::jsonb as claims
  ), raw_role as (
    select trim(coalesce(claims ->> 'app_role', claims -> 'app_metadata' ->> 'app_role', '')) as role
    from raw_claims
  )
  select case role
    when 'Supervisor' then 'Superintendent'
    when 'Technician' then 'Assistant'
    when 'Editor' then 'Engineer'
    when 'Admin' then 'Admin'
    when 'Manager' then 'Manager'
    when 'Superintendent' then 'Superintendent'
    when 'Drilling Manager' then 'Drilling Manager'
    when 'Asset Manager' then 'Asset Manager'
    when 'Maintenance Manager' then 'Maintenance Manager'
    when 'Project Manager' then 'Project Manager'
    when 'Engineer' then 'Engineer'
    when 'Assistant' then 'Assistant'
    when 'Viewer' then 'Viewer'
    else 'Viewer'
  end
  from raw_role;
$$;

comment on function public.app_role() is
'Normalized app role for RLS. Canonical roles: Admin, Manager, Superintendent, Drilling Manager, Asset Manager, Maintenance Manager, Project Manager, Engineer, Assistant, Viewer. Legacy aliases: Supervisor->Superintendent, Technician->Assistant, Editor->Engineer.';

create or replace function public.app_role_is_manager_tier()
returns boolean
language sql
stable
as $$
  select public.app_role() in (
    'Admin',
    'Manager',
    'Superintendent',
    'Drilling Manager',
    'Asset Manager',
    'Maintenance Manager',
    'Project Manager'
  );
$$;

comment on function public.app_role_is_manager_tier() is
'Returns true for the manager-tier roles recognized by the Worker permission matrix.';

-- Example predicates for table policies should use the normalized vocabulary above,
-- e.g. `public.app_role() in (''Admin'',''Manager'',''Superintendent'')`.
