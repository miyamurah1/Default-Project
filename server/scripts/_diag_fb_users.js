// Temporary read-only diagnostic: list Firebase Auth users (no secrets).
import { readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

let sa = process.env.FIREBASE_SERVICE_ACCOUNT;
const raw = sa
  ? JSON.parse(sa)
  : JSON.parse(readFileSync(new URL('../firebase-service-account.json', import.meta.url), 'utf8'));
initializeApp({ credential: cert(raw) });

const auth = getAuth();
let page = await auth.listUsers(1000);
const rows = [];
for (;;) {
  for (const u of page.users) {
    rows.push({
      uid: u.uid,
      email: u.email ?? '',
      disabled: u.disabled,
      has_password: !!u.passwordHash,
      providers: (u.providerData ?? []).map((p) => p.providerId).join(','),
    });
  }
  if (!page.pageToken) break;
  page = await auth.listUsers(1000, page.pageToken);
}
console.log('FIREBASE AUTH USERS:', rows.length);
console.table(rows);
process.exit(0);
