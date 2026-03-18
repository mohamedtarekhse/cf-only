-- 030_add_login_history.sql
-- Add canonical login history storage for authentication events.
-- Idempotent: safe to run multiple times.

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS login_history (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id      UUID NOT NULL,
  logged_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address   TEXT,
  user_agent   TEXT,
  CONSTRAINT login_history_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES app_users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_login_history_user_id ON login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_logged_in_at ON login_history(logged_in_at DESC);

COMMIT;
