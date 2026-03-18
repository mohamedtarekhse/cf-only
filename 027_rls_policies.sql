-- Canonical application roles must match `_worker.js` exactly:
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
-- Legacy-only values are normalized here for compatibility while the rest of
-- the application stores and emits canonical strings:
--   Editor    -> Engineer
--   Supervisor -> Superintendent
--   Technician -> Assistant

create schema if not exists app;

create or replace function app.current_app_role()
returns text
language sql
stable
as $$
  select case trim(coalesce(auth.jwt() ->> 'app_role', auth.jwt() -> 'app_metadata' ->> 'app_role', 'Viewer'))
    when 'Editor' then 'Engineer'
    when 'Supervisor' then 'Superintendent'
    when 'Technician' then 'Assistant'
    else trim(coalesce(auth.jwt() ->> 'app_role', auth.jwt() -> 'app_metadata' ->> 'app_role', 'Viewer'))
  end;
$$;

create or replace function app.is_allowed_role()
returns boolean
language sql
stable
as $$
  select app.current_app_role() in (
    'Admin',
    'Manager',
    'Superintendent',
    'Drilling Manager',
    'Asset Manager',
    'Maintenance Manager',
    'Project Manager',
    'Engineer',
    'Assistant',
    'Viewer'
  );
$$;

create or replace function app.is_manager_tier()
returns boolean
language sql
stable
as $$
  select app.current_app_role() in (
    'Manager',
    'Superintendent',
    'Drilling Manager',
    'Asset Manager',
    'Maintenance Manager',
    'Project Manager'
  );
$$;

create or replace function app.can_approve_transfer_stage(stage text)
returns boolean
language sql
stable
as $$
  select case stage
    when 'stage1' then app.current_app_role() in ('Admin', 'Manager', 'Superintendent')
    when 'stage2' then app.current_app_role() in ('Admin', 'Manager', 'Drilling Manager')
    when 'stage3' then app.current_app_role() in ('Admin', 'Manager', 'Asset Manager')
    else false
  end;
$$;

do $$
begin
  if to_regclass('public.app_users') is not null then
    execute 'alter table public.app_users enable row level security';

    execute 'drop policy if exists app_users_select on public.app_users';
    execute $policy$
      create policy app_users_select on public.app_users
      for select
      to authenticated
      using (
        app.is_allowed_role()
        and (
          app.current_app_role() = ''Admin''
          or id::text = auth.jwt() ->> ''sub''
        )
      )
    $policy$;

    execute 'drop policy if exists app_users_insert on public.app_users';
    execute $policy$
      create policy app_users_insert on public.app_users
      for insert
      to authenticated
      with check (
        app.is_allowed_role()
        and app.current_app_role() = ''Admin''
        and role in (
          ''Admin'',
          ''Manager'',
          ''Superintendent'',
          ''Drilling Manager'',
          ''Asset Manager'',
          ''Maintenance Manager'',
          ''Project Manager'',
          ''Engineer'',
          ''Assistant'',
          ''Viewer''
        )
      )
    $policy$;

    execute 'drop policy if exists app_users_update on public.app_users';
    execute $policy$
      create policy app_users_update on public.app_users
      for update
      to authenticated
      using (
        app.is_allowed_role()
        and (
          app.current_app_role() = ''Admin''
          or id::text = auth.jwt() ->> ''sub''
        )
      )
      with check (
        app.is_allowed_role()
        and (
          app.current_app_role() = ''Admin''
          or id::text = auth.jwt() ->> ''sub''
        )
        and role in (
          ''Admin'',
          ''Manager'',
          ''Superintendent'',
          ''Drilling Manager'',
          ''Asset Manager'',
          ''Maintenance Manager'',
          ''Project Manager'',
          ''Engineer'',
          ''Assistant'',
          ''Viewer''
        )
      )
    $policy$;

    execute 'drop policy if exists app_users_delete on public.app_users';
    execute $policy$
      create policy app_users_delete on public.app_users
      for delete
      to authenticated
      using (
        app.is_allowed_role()
        and app.current_app_role() = ''Admin''
      )
    $policy$;
  end if;
end
$$;
