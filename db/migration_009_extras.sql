-- Migration 009: password reset, due dates, run-log hygiene.
--
-- password_reset_codes: 6-digit codes (bcrypt-hashed at rest),
-- 15-minute expiry, single-use. In dev the code goes to the server
-- log; in prod the same code goes out by email (see forgot route).
--
-- tasks.due_at: optional deadline shown on cards + detail.
--
-- rule_runs pruning: the run log is append-only, so a trigger caps
-- each rule at its newest 200 runs. History stays, bloat doesn't.

CREATE TABLE IF NOT EXISTS password_reset_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '15 minutes',
  used BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reset_user
  ON password_reset_codes (user_id, created_at DESC);

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS due_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_tasks_due
  ON tasks (user_id, due_at) WHERE due_at IS NOT NULL;

CREATE OR REPLACE FUNCTION prune_rule_runs() RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM rule_runs WHERE id IN (
    SELECT id FROM rule_runs
    WHERE rule_id = NEW.rule_id
    ORDER BY created_at DESC OFFSET 200);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prune_runs ON rule_runs;
CREATE TRIGGER trg_prune_runs
  AFTER INSERT ON rule_runs
  FOR EACH ROW EXECUTE FUNCTION prune_rule_runs();
