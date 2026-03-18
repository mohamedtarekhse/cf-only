-- Align notifications schema with Worker/UI runtime fields.
-- Canonical severity field is `kind`.

BEGIN;

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS kind text,
  ADD COLUMN IF NOT EXISTS link text,
  ADD COLUMN IF NOT EXISTS user_id bigint,
  ADD COLUMN IF NOT EXISTS client_id text,
  ADD COLUMN IF NOT EXISTS event_type text;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'notifications'
      AND column_name = 'type'
  ) THEN
    EXECUTE 'UPDATE notifications SET kind = COALESCE(NULLIF(kind, ''''), type) WHERE type IS NOT NULL';
  END IF;
END $$;

UPDATE notifications
SET kind = COALESCE(NULLIF(kind, ''), 'info')
WHERE kind IS NULL OR kind = '';

ALTER TABLE notifications
  ALTER COLUMN kind SET DEFAULT 'info';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'notifications'
      AND column_name = 'type'
  ) THEN
    EXECUTE 'ALTER TABLE notifications DROP COLUMN type';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS notifications_unread_user_created_idx
  ON notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_unread_client_user_created_idx
  ON notifications (client_id, user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS notifications_event_type_created_idx
  ON notifications (event_type, created_at DESC);

COMMIT;
