// API + DB probe (run: $env:NODE_ENV='test'; $env:TEST_BYPASS_TOKEN='ci-local-secret'; node api-probe.js)
import pg from 'pg';
const BASE = process.env.TEST_API ?? 'http://localhost:8080';
const BYPASS = process.env.TEST_BYPASS_TOKEN;
if (!BYPASS) { console.error('no bypass env'); process.exit(1); }
const stamp = Date.now().toString(36);
const tokenFor = (n) => `${BYPASS}:${n}-${stamp}@test.local`;
async function api(method, path, { token, body } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let json = null;
  try { json = await res.json(); } catch {}
  console.log(`API:${method} ${path.padEnd(34)} -> ${res.status} body=${JSON.stringify(json).slice(0, 110)}`);
  return { status: res.status, json };
}
(async () => {
  const t = tokenFor('t');
  await api('GET', '/api/auth/me', { token: t });
  const create = await api('POST', '/api/tasks', { token: t, body: { title: 'Batch probe one', tag: 'ZZZQ' } });
  const hits = await api('GET', '/api/tasks/search?q=zzzq', { token: t });
  const exportR = await api('GET', '/api/export', { token: t });
  const tasks = await api('GET', '/api/tasks', { token: t });
})().catch((e) => { console.error('API ERR', e); process.exit(1); });
