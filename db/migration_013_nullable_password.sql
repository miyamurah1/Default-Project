-- Migration 013: Firebase is the password manager now, so local
-- password hashes are legacy. Allow NULL so firebase-sync can insert
-- brand-new users (previously every new signup 500d on NOT NULL).

ALTER TABLE users
  ALTER COLUMN password_hash DROP NOT NULL;
