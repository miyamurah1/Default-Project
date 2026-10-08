-- Migration 003: authentication (run after schema.sql).
-- Users table for email + password login. Passwords are NEVER stored
-- in plain text — only bcrypt hashes (see server/src/index.js).

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL DEFAULT '',
  avatar_label TEXT NOT NULL DEFAULT '禅',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lowercase emails so 'A@x.com' and 'a@x.com' can't both register.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_lower
  ON users (lower(email));
