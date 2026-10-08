// One-off cleanup: remove e2e test users created during auth verification.
import 'dotenv/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { readFileSync } from 'node:fs';
import pg from 'pg';

const app =
  getApps()[0] ??
  initializeApp({
    credential: cert(JSON.parse(readFileSync('./firebase-service-account.json', 'utf8'))),
  });
const auth = getAuth(app);
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

const users = (await auth.listUsers()).users.filter(
  (u) => u.email && u.email.startsWith('e2e-auth-test'),
);
for (const u of users) {
  await auth.deleteUser(u.uid);
  await pool.query('DELETE FROM users WHERE firebase_uid = $1', [u.uid]);
  console.log('deleted', u.email);
}
console.log('cleanup done (' + users.length + ' users)');
await pool.end();
