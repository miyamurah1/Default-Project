// End-to-end check that the demo account really signs in: password grant
// against Firebase (same endpoint the Flutter web app calls), then the API
// calls the app makes right after login.
//
// Usage: node scripts/verify_demo_login.js [email] [password]
import { readFileSync } from 'node:fs';

const EMAIL = (process.argv[2] ?? 'demo@dailybloom.app').toLowerCase().trim();
const PASSWORD = process.argv[3] ?? 'Bloom12345!';
const API = process.env.API_URL ?? 'http://localhost:8080';

// Web API key straight out of the Flutter config, so this can never drift
// from what the browser sends.
const dart = readFileSync(new URL('../../lib/firebase_options.dart', import.meta.url), 'utf8');
const apiKey = dart.match(/apiKey:\s*'([^']+)'/)?.[1];
if (!apiKey) throw new Error('could not read the web apiKey from lib/firebase_options.dart');

const signIn = await fetch(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: EMAIL, password: PASSWORD, returnSecureToken: true }),
  },
);
const signInJson = await signIn.json();
if (!signInJson.idToken) {
  console.log('SIGN-IN FAILED', signIn.status, JSON.stringify(signInJson));
  process.exit(1);
}
console.log('sign-in OK  ->', signInJson.localId, '|', signInJson.email);

const auth = { Authorization: `Bearer ${signInJson.idToken}`, 'Content-Type': 'application/json' };

const call = async (path, init = {}) => {
  const res = await fetch(`${API}${path}`, { ...init, headers: { ...auth, ...(init.headers ?? {}) } });
  const body = await res.text();
  return { status: res.status, body };
};

const sync = await call('/api/auth/firebase-sync', { method: 'POST', body: JSON.stringify({}) });
console.log('firebase-sync ->', sync.status, sync.body.slice(0, 160));

const me = await call('/api/auth/me');
console.log('auth/me       ->', me.status, me.body.slice(0, 160));

const list = await call('/api/tasks?include=subtasks');
const tasks = JSON.parse(list.body);
const perTask = tasks.map((t) => (t.subtasks ?? []).length);
console.log('tasks         ->', list.status, '| total:', tasks.length,
  '| with subtasks embedded:', perTask.filter((n) => n > 0).length,
  '| min/max subs:', Math.min(...perTask), '/', Math.max(...perTask));
console.log('sample        ->', JSON.stringify(tasks[0]).slice(0, 220));

const heat = await call('/api/heatmap?weeks=12');
console.log('heatmap       ->', heat.status, '| active days:', JSON.parse(heat.body).length);

const prog = await call('/api/progress');
console.log('progress      ->', prog.status, prog.body.slice(0, 200));

const ins = await call('/api/insights');
console.log('insights      ->', ins.status, '| tags:', JSON.parse(ins.body).byTag?.length);

process.exit(0);
