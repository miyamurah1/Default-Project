-- Migration 006: Phase B — focus timer sessions.
--
-- focus_sessions records every started timer: what task, which mode
-- (focus | break), how long was planned vs actual, and whether it ran
-- to completion. Abandoned sessions are kept (completed = false) so
-- history stays honest. This table feeds Phase D insights.
--
-- Also adds the 'focus_done' flow trigger: finishing a focus session
-- fires rules like any other task event.

CREATE TABLE IF NOT EXISTS focus_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  mode TEXT NOT NULL DEFAULT 'focus'
    CHECK (mode IN ('focus', 'break')),
  planned_minutes INT NOT NULL DEFAULT 25,
  actual_minutes INT NOT NULL DEFAULT 0,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_focus_task
  ON focus_sessions (task_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_focus_user_day
  ON focus_sessions (user_id, started_at DESC);

-- Widen the rules trigger allow-list (constraint name is the
-- Postgres default for the CHECK declared in migration 005).
ALTER TABLE rules DROP CONSTRAINT IF EXISTS rules_trigger_check;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rules_trigger_check') THEN
    ALTER TABLE rules ADD CONSTRAINT rules_trigger_check CHECK (trigger IN (
      'task_created', 'task_moved', 'task_done',
      'note_added', 'subtasks_complete', 'focus_done'
    ));
  END IF;
END $$;
