-- Migration 004: Phase A — task history + subtasks.
--
-- task_events is the audit trail behind the per-task timeline ("flow")
-- and the global activity feed. Rows are written by the API whenever a
-- task is created, moved, renamed, or gets a user note. They are never
-- updated or deleted by the app (append-only history).
--
-- subtasks are a single-level checklist under a parent task.

CREATE TABLE IF NOT EXISTS task_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  kind TEXT NOT NULL
    CHECK (kind IN ('created', 'status', 'renamed', 'note')),
  from_status TEXT,
  to_status TEXT,
  body TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_task_events_task
  ON task_events (task_id, created_at);

CREATE TABLE IF NOT EXISTS subtasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  done BOOLEAN NOT NULL DEFAULT FALSE,
  position INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subtasks_task
  ON subtasks (task_id, position, created_at);

-- Backfill: existing tasks get a 'created' event so their timelines
-- don't start empty. Re-runnable (skips tasks that already have one).
INSERT INTO task_events (task_id, kind, to_status, created_at)
SELECT t.id, 'created', t.status, t.created_at
FROM tasks t
WHERE NOT EXISTS (
  SELECT 1 FROM task_events e
  WHERE e.task_id = t.id AND e.kind = 'created'
);
