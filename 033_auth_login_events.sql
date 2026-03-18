-- ============================================================================
-- 033_auth_login_events.sql
-- Adds a login audit trail table for successful authentication events.
-- ============================================================================

create extension if not exists pgcrypto;

create table if not exists public.auth_login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.app_users(id) on delete set null,
  email text not null,
  logged_in_at timestamptz not null default now(),
  ip_address text,
  user_agent text,
  client_id text,
  status text not null default 'success'
    check (status in ('success', 'failed', 'locked', 'revoked'))
);

create index if not exists idx_auth_login_events_user_logged_in_at
  on public.auth_login_events (user_id, logged_in_at desc);

create index if not exists idx_auth_login_events_client_logged_in_at
  on public.auth_login_events (client_id, logged_in_at desc);

create index if not exists idx_auth_login_events_email_logged_in_at
  on public.auth_login_events (email, logged_in_at desc);
