-- Migration 010: short-lived access + rotating refresh tokens,
-- and idempotent task creation (offline outbox retries).
--
-- refresh_tokens: one row per issued refresh token. Lookup is by
-- SHA-256 hash (the raw token only ever travels once, at issuance).
-- Rotation revokes the presented token and mints a pair; logout and
-- account deletion cascade/revoke accordingly.
--
-- tasks.client_id: app-generated idempotency key for creates. A retry
-- of the same queued create returns the original row instead of a
-- duplicate. Nullable so old rows stay valid; unique when present.

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '30 days',
  revoked BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_user
  ON refresh_tokens (user_id, created_at DESC);

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS client_id TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'tasks_client_unique') THEN
    ALTER TABLE tasks
      ADD CONSTRAINT tasks_client_unique UNIQUE (client_id);
  END IF;
END $$;
