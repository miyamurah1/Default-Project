-- Migration 011: task description, priority, reordering, recurring rules,
-- and reversible heatmap contribution trigger.

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS priority TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS position INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS recurring TEXT NOT NULL DEFAULT 'none';

CREATE INDEX IF NOT EXISTS idx_tasks_user_status_pos
  ON tasks (user_id, status, position);

CREATE INDEX IF NOT EXISTS idx_subtasks_task_pos
  ON subtasks (task_id, position);

-- Reversible heatmap contribution trigger:
-- Increment when moving to 'done', decrement when unchecking 'done'.
CREATE OR REPLACE FUNCTION bump_contribution() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'done' AND (OLD.status IS DISTINCT FROM 'done') THEN
    NEW.completed_at = COALESCE(NEW.completed_at, now());
    IF NEW.user_id IS NOT NULL THEN
      INSERT INTO contributions (user_id, day, count)
      VALUES (NEW.user_id, (NEW.completed_at AT TIME ZONE 'UTC')::date, 1)
      ON CONFLICT (user_id, day) DO UPDATE SET count = contributions.count + 1;
    END IF;
  ELSIF (OLD.status = 'done') AND NEW.status != 'done' THEN
    IF OLD.user_id IS NOT NULL AND OLD.completed_at IS NOT NULL THEN
      UPDATE contributions
      SET count = GREATEST(0, count - 1)
      WHERE user_id = OLD.user_id AND day = (OLD.completed_at AT TIME ZONE 'UTC')::date;
    END IF;
    NEW.completed_at = NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
