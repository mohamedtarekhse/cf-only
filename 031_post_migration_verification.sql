-- 031_post_migration_verification.sql
-- Run after 030_safe_non_breaking_migration-base.sql to verify password_changed_at updates.

BEGIN;

WITH seeded_user AS (
  INSERT INTO public.app_users (email, name, password, active)
  VALUES ('trigger-verification@example.com', 'Trigger Verification', 'old-password', TRUE)
  ON CONFLICT (email) DO UPDATE
    SET password = EXCLUDED.password,
        active = TRUE,
        updated_at = NOW()
  RETURNING id, email, password_changed_at AS before_password_changed_at, updated_at AS before_updated_at
),
wait_for_clock AS (
  SELECT pg_sleep(1)
),
updated_user AS (
  UPDATE public.app_users
  SET password = 'new-password'
  WHERE id = (SELECT id FROM seeded_user)
    AND EXISTS (SELECT 1 FROM wait_for_clock)
  RETURNING id, email, password_changed_at AS after_password_changed_at, updated_at AS after_updated_at
)
SELECT
  s.id,
  s.email,
  s.before_password_changed_at,
  u.after_password_changed_at,
  (u.after_password_changed_at > s.before_password_changed_at) AS password_changed_at_advanced,
  s.before_updated_at,
  u.after_updated_at,
  (u.after_updated_at >= u.after_password_changed_at) AS updated_at_touched
FROM seeded_user s
JOIN updated_user u USING (id, email);

ROLLBACK;
