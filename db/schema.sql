-- Daily Bloom schema — Kanban tasks + GitHub-style contributions.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  tag TEXT NOT NULL DEFAULT 'General',
  status TEXT NOT NULL DEFAULT 'todo'
    CHECK (status IN ('todo', 'in_progress', 'done')),
  comments INT NOT NULL DEFAULT 0,
  avatar_label TEXT NOT NULL DEFAULT '禅',
  folder TEXT NOT NULL DEFAULT 'Productivity',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- One row per day, like a git contribution counter.
CREATE TABLE IF NOT EXISTS contributions (
  day DATE PRIMARY KEY,
  count INT NOT NULL DEFAULT 0
);

CREATE OR REPLACE FUNCTION bump_contribution() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'done' AND (OLD.status IS DISTINCT FROM 'done') THEN
    NEW.completed_at = COALESCE(NEW.completed_at, now());
    INSERT INTO contributions (day, count)
    VALUES ((NEW.completed_at AT TIME ZONE 'UTC')::date, 1)
    ON CONFLICT (day) DO UPDATE SET count = contributions.count + 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bump_contribution ON tasks;
CREATE TRIGGER trg_bump_contribution
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION bump_contribution();

CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks (status);
CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks (completed_at);
CREATE INDEX IF NOT EXISTS idx_tasks_folder ON tasks (folder);

CREATE TABLE IF NOT EXISTS folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  icon TEXT NOT NULL DEFAULT 'folder',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
