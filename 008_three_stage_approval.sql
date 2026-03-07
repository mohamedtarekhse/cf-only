-- 3-Stage Transfer Approval: add Superintendent columns
ALTER TABLE transfers
  ADD COLUMN IF NOT EXISTS supt_approved_by   TEXT,
  ADD COLUMN IF NOT EXISTS supt_approved_date DATE,
  ADD COLUMN IF NOT EXISTS supt_action        TEXT CHECK (supt_action IN ('approve','reject','hold')),
  ADD COLUMN IF NOT EXISTS supt_comment       TEXT;

-- Update status CHECK to include new intermediate statuses
ALTER TABLE transfers DROP CONSTRAINT IF EXISTS transfers_status_check;
ALTER TABLE transfers ADD CONSTRAINT transfers_status_check
  CHECK (status IN ('Pending','Supt Approved','Drilling Approved','Completed','Rejected','On Hold'));

NOTIFY pgrst, 'reload schema';
