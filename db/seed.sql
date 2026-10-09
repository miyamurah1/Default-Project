-- Seed demo content for FRESH databases. Fully re-runnable: every
-- block below is a no-op when its table already holds rows, so the
-- migrate runner (and re-deploys) can execute this file repeatedly.
-- NOTE: seed rows carry no user; migration 008 assigns them to the
-- most active account. Fresh cloud deploys therefore start empty
-- until the first user signs up — by design.

INSERT INTO folders (name, icon)
SELECT v.name, v.icon
FROM (VALUES
  ('Productivity', 'folder'),
  ('Self Care', 'heart'),
  ('Personal Projects', 'star')
) AS v(name, icon)
WHERE NOT EXISTS (SELECT 1 FROM folders)
ON CONFLICT DO NOTHING;

INSERT INTO tasks (title, tag, status, comments, avatar_label, folder)
SELECT v.title, v.tag, v.status, v.comments, v.avatar_label, v.folder
FROM (VALUES
  ('Refine the visual hierarchy for the zen mode dashboard', 'Design', 'todo', 2, '禅', 'Productivity'),
  ('Review user feedback on the new habit tracking animations', 'Product', 'todo', 5, '和', 'Productivity'),
  ('Prepare 25-min pomodoro set for deep work sprint', 'Focus', 'todo', 1, '集中', 'Self Care'),
  ('Polish contribution heatmap shades for Sakura theme', 'Design', 'in_progress', 3, '桜', 'Personal Projects'),
  ('Draft inbox empty-state copy in calm tone', 'Product', 'in_progress', 0, '静', 'Productivity'),
  ('Morning meditation + journal setup', 'Ritual', 'done', 0, '朝', 'Self Care'),
  ('Ship Kanban tab skeleton UI', 'Build', 'done', 4, '建', 'Productivity'),
  ('Clean up backlog and archive old cards', 'Care', 'done', 1, '掃', 'Personal Projects'),
  ('Evening shutdown checklist', 'Ritual', 'done', 0, '夜', 'Self Care')
) AS v(title, tag, status, comments, avatar_label, folder)
WHERE NOT EXISTS (SELECT 1 FROM tasks)
ON CONFLICT DO NOTHING;

-- Backfill contributions for the last 84 days (12 weeks), deterministic pattern.
-- Bare ON CONFLICT: seed rows carry no user and must never clash with
-- real per-user history (app queries always filter by user_id).
INSERT INTO contributions (day, count)
SELECT d::date,
  CASE (EXTRACT(DOY FROM d)::int % 7)
    WHEN 0 THEN 0 WHEN 1 THEN 2 WHEN 2 THEN 1 WHEN 3 THEN 4
    WHEN 4 THEN 1 WHEN 5 THEN 3 ELSE 2 END
FROM generate_series(CURRENT_DATE - INTERVAL '83 days', CURRENT_DATE, INTERVAL '1 day') AS d
WHERE NOT EXISTS (SELECT 1 FROM contributions)
ON CONFLICT DO NOTHING;

-- Make today + yesterday pop like the gold peak in the design.
-- The contributions table has no user_id column (line 20 of schema.sql),
-- so drop this bogus predicate. (Found while validating deploy: a fresh
-- db's `migrate` crashed here with SQLSTATE 42703, blocking boot.)
DELETE FROM contributions
WHERE day IN (CURRENT_DATE, CURRENT_DATE - 1);
INSERT INTO contributions (day, count) VALUES (CURRENT_DATE, 5), (CURRENT_DATE - 1, 4)
ON CONFLICT DO NOTHING;
