-- Auth activity records distinguish explicit credential logins from session restores/app opens.
CREATE TABLE IF NOT EXISTS auth_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id text,
  email text,
  client_id text,
  event_type text NOT NULL CHECK (event_type IN ('login', 'session_restored')),
  event_source text NOT NULL DEFAULT 'web',
  session_storage text,
  ip_address text,
  user_agent text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS auth_activity_user_created_idx
  ON auth_activity (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS auth_activity_email_created_idx
  ON auth_activity (email, created_at DESC);

CREATE INDEX IF NOT EXISTS auth_activity_event_created_idx
  ON auth_activity (event_type, created_at DESC);
