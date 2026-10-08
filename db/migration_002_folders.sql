-- Migration 002: folders (run after schema.sql / seed.sql).
CREATE TABLE IF NOT EXISTS folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  icon TEXT NOT NULL DEFAULT 'folder',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO folders (name, icon) VALUES
  ('Productivity', 'folder'),
  ('Self Care', 'heart'),
  ('Personal Projects', 'star')
ON CONFLICT (name) DO NOTHING;
