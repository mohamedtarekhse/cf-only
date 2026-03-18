-- Add password change tracking for session/JWT invalidation.
-- Idempotent by design: safe to re-run.

ALTER TABLE IF EXISTS public.app_users
  ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;

UPDATE public.app_users
SET password_changed_at = NOW()
WHERE password IS NOT NULL
  AND password_changed_at IS NULL;

-- Index intentionally omitted by default.
-- `password_changed_at` is read alongside point lookups by `id` in the worker,
-- so a standalone index is usually unnecessary unless future reporting or
-- large-user filtering queries begin scanning this column directly.
