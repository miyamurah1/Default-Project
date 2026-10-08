-- Migration 008: per-user isolation for tasks, folders, contributions.
--
-- Before this, every account saw the same workspace. Now each row
-- belongs to the user who created it (user_id), and every API query
-- filters by the logged-in user. Subtasks, events, focus rows, runs
-- and inbox were already user-linked (directly or via CASCADE).
--
-- Backfill assigns all existing rows to the most active user
-- (by history events), falling back to the oldest account.

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE folders
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE contributions
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

DO $$
DECLARE owner UUID;
BEGIN
  SELECT user_id INTO owner
  FROM task_events WHERE user_id IS NOT NULL
  GROUP BY user_id ORDER BY COUNT(*) DESC LIMIT 1;
  IF owner IS NULL THEN
    SELECT id INTO owner FROM users ORDER BY created_at LIMIT 1;
  END IF;
  IF owner IS NOT NULL THEN
    UPDATE tasks SET user_id = owner WHERE user_id IS NULL;
    UPDATE folders SET user_id = owner WHERE user_id IS NULL;
    UPDATE contributions SET user_id = owner WHERE user_id IS NULL;
  END IF;
END $$;

-- Folder names are unique per user now, not globally.
ALTER TABLE folders DROP CONSTRAINT IF EXISTS folders_name_key;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'folders_user_name_unique') THEN
    ALTER TABLE folders
      ADD CONSTRAINT folders_user_name_unique UNIQUE (user_id, name);
  END IF;
END $$;

-- Contributions are keyed per user per day (PK can't hold the
-- nullable user_id, a UNIQUE can — and NULL owners can't occur:
-- the trigger only fires on user-owned task updates).
ALTER TABLE contributions DROP CONSTRAINT IF EXISTS contributions_pkey;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contributions_user_day_unique') THEN
    ALTER TABLE contributions
      ADD CONSTRAINT contributions_user_day_unique UNIQUE (user_id, day);
  END IF;
END $$;

-- The heatmap trigger stamps the task owner's id on each bump.
CREATE OR REPLACE FUNCTION bump_contribution() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'done' AND (OLD.status IS DISTINCT FROM 'done') THEN
    NEW.completed_at = COALESCE(NEW.completed_at, now());
    INSERT INTO contributions (user_id, day, count)
    VALUES (NEW.user_id, (NEW.completed_at AT TIME ZONE 'UTC')::date, 1)
    ON CONFLICT (user_id, day) DO UPDATE SET count = contributions.count + 1;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
