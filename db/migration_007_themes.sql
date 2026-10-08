-- Migration 007: theme store — ownership + equipped theme.
--
-- owned_themes: which theme ids each user bought (Edo is free and
-- granted to everyone). users.active_theme: currently equipped id.
-- Prices and palettes live in code (server THEMES + Flutter palettes);
-- the database only tracks ownership, balance does the rest.

CREATE TABLE IF NOT EXISTS owned_themes (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme_id TEXT NOT NULL,
  purchased_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, theme_id)
);

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS active_theme TEXT NOT NULL DEFAULT 'edo';

-- Everyone already owns Edo (it was the only look).
INSERT INTO owned_themes (user_id, theme_id)
SELECT id, 'edo' FROM users
ON CONFLICT DO NOTHING;
