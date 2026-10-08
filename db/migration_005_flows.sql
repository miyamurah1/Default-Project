-- Migration 005: n8n-style flows — rules engine + wallet + inbox.
--
-- rules: one automation = WHEN trigger + IF condition THEN actions.
--   trigger: task_created | task_moved | task_done | note_added | subtasks_complete
--   condition: {} (always) or {field, op, value}, e.g.
--     {"field":"tag","op":"equals","value":"Design"}
--   actions: [{type, ...params}], e.g.
--     [{"type":"award_tokens","amount":10},{"type":"inbox","title":"Nice!","body":"..."}]
--
-- rule_runs: append-only execution log (success | skipped | failed).
--
-- user_tokens: token wallet backing the STORE balance (was hardcoded 450).
-- inbox_messages: real inbox backing InboxScreen (was static mock data).

CREATE TABLE IF NOT EXISTS user_tokens (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance INT NOT NULL DEFAULT 450,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Existing users start where the UI always claimed they were.
INSERT INTO user_tokens (user_id, balance)
SELECT id, 450 FROM users
ON CONFLICT (user_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS inbox_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tag TEXT NOT NULL DEFAULT 'AUTOMATION',
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  unread BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inbox_user
  ON inbox_messages (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  trigger TEXT NOT NULL
    CHECK (trigger IN ('task_created', 'task_moved', 'task_done', 'note_added', 'subtasks_complete')),
  condition JSONB NOT NULL DEFAULT '{}',
  actions JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rules_user
  ON rules (user_id, enabled);

CREATE TABLE IF NOT EXISTS rule_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  rule_id UUID NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
  task_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
  task_title TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL
    CHECK (status IN ('success', 'skipped', 'failed')),
  detail JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_runs_rule
  ON rule_runs (rule_id, created_at DESC);
