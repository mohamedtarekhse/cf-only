-- Align notifications with the active application contract used by `_worker.js`
-- and `index.html`.
BEGIN;

ALTER TABLE IF EXISTS notifications
  ADD COLUMN IF NOT EXISTS kind text,
  ADD COLUMN IF NOT EXISTS link text,
  ADD COLUMN IF NOT EXISTS user_id text,
  ADD COLUMN IF NOT EXISTS client_id text,
  ADD COLUMN IF NOT EXISTS event_type text,
  ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'notifications'
      AND column_name = 'type'
  ) AND NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'notifications'
      AND column_name = 'kind'
  ) THEN
    ALTER TABLE notifications RENAME COLUMN type TO kind;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'notifications'
      AND column_name = 'type'
  ) THEN
    EXECUTE $sql$
      UPDATE notifications
      SET kind = CASE
        WHEN kind IS NOT NULL AND btrim(kind) <> '' THEN kind
        WHEN type IS NOT NULL AND btrim(type) <> '' THEN CASE
          WHEN lower(type) IN ('ni-green', 'success') THEN 'green'
          WHEN lower(type) IN ('ni-red', 'error') THEN 'red'
          WHEN lower(type) IN ('ni-orange', 'warning') THEN 'orange'
          WHEN lower(type) IN ('ni-blue', 'info') THEN 'blue'
          ELSE regexp_replace(lower(type), '^ni-', '')
        END
        ELSE 'blue'
      END
    $sql$;
  ELSE
    UPDATE notifications
    SET kind = COALESCE(NULLIF(btrim(kind), ''), 'blue');
  END IF;
END $$;

UPDATE notifications
SET is_read = COALESCE(is_read, false),
    created_at = COALESCE(created_at, now()),
    link = NULLIF(link, ''),
    event_type = NULLIF(event_type, ''),
    user_id = NULLIF(user_id, ''),
    client_id = NULLIF(client_id, '');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'notifications'
      AND column_name = 'type'
  ) THEN
    ALTER TABLE notifications DROP COLUMN type;
  END IF;
END $$;

ALTER TABLE IF EXISTS notifications
  ALTER COLUMN kind SET NOT NULL,
  ALTER COLUMN is_read SET DEFAULT false,
  ALTER COLUMN is_read SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT now(),
  ALTER COLUMN created_at SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread_created_at
  ON notifications (user_id, created_at DESC)
  WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_notifications_client_user_unread_created_at
  ON notifications (client_id, user_id, created_at DESC)
  WHERE is_read = false;

COMMIT;
