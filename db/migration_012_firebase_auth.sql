-- Migration 012: Add firebase_uid column to users table for Firebase Auth migration.
-- Existing users keep all their data; firebase_uid is populated on next sign-in
-- via the /api/auth/firebase-sync endpoint (upsert by email).

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS firebase_uid TEXT UNIQUE;

-- Index for the fast lookup in requireAuth middleware.
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid
  ON users (firebase_uid)
  WHERE firebase_uid IS NOT NULL;

-- firebase_uid + email index for the upsert query in firebase-sync.
CREATE INDEX IF NOT EXISTS idx_users_email_lower
  ON users (lower(email));
