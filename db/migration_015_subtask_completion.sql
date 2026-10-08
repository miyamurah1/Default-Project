-- Migration 015: subtask completion becomes final + dated.
--
-- completed_at records when a subtask was checked off (NULL = open).
-- The API rejects un-checking once completed_at is set, so "done is
-- done" is enforced at the data layer, not just in the UI.
-- created_at (004) already serves as the start date.

ALTER TABLE subtasks
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Backfill: subtasks already done get "now" as their completion time.
-- Re-runnable (only touches rows still missing it).
UPDATE subtasks
  SET completed_at = now()
  WHERE done AND completed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_subtasks_completed
  ON subtasks (task_id, completed_at)
  WHERE completed_at IS NOT NULL;
