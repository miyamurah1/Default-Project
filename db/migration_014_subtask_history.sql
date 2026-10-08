-- Migration 014: subtask ticks become history.
--
-- Subtask check/uncheck now writes a task_events row (kind 'subtask',
-- to_status 'done'/'todo', body = subtask title), so per-subtask
-- history shows in timelines, activity, and the History screen.

ALTER TABLE task_events DROP CONSTRAINT IF EXISTS task_events_kind_check;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'task_events_kind_check') THEN
    ALTER TABLE task_events ADD CONSTRAINT task_events_kind_check CHECK (kind IN (
      'created', 'status', 'renamed', 'note', 'subtask'
    ));
  END IF;
END $$;
