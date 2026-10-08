// One-off stress seed: ~500 tasks + 300 subtasks for load testing.
// Idempotent: wipes this account's previous STRESS rows first.
// Usage: node scripts/stress_seed.js [email] [scale]
//   scale multiplies volumes (default 1 -> 500 tasks).
import pg from 'pg';
const pool = new pg.Pool({
  connectionString:
    'postgres://bloom:bloom_dev_password@localhost:5433/daily_bloom',
});

const email = process.argv[2] ?? 'aaa@gmail.com';
const scale = Math.max(1, parseInt(process.argv[3] ?? '1', 10));
const N_TODO = 300 * scale;
const N_PROG = 100 * scale;
const N_DONE = 100 * scale;
const N_SUB_TASKS = 100 * scale; // first N todo tasks get 3 subs each
const N_SUBS_EACH = 3;

const { rows: u } = await pool.query(
  'SELECT id FROM users WHERE email = $1', [email]);
if (!u.length) throw new Error(`no such user: ${email}`);
const uid = u[0].id;
const t0 = Date.now();

// Idempotency: clear previous stress rows for this account.
await pool.query(`DELETE FROM subtasks WHERE task_id IN
  (SELECT id FROM tasks WHERE user_id = $1 AND title LIKE 'STRESS-%')`,
  [uid]);
await pool.query(
  `DELETE FROM tasks WHERE user_id = $1 AND title LIKE 'STRESS-%'`,
  [uid]);
for (const name of ['Stress', 'Stress Archive']) {
  await pool.query(
    `INSERT INTO folders (user_id, name, icon)
     SELECT $1, $2, 'folder'
     WHERE NOT EXISTS (SELECT 1 FROM folders WHERE user_id = $1 AND name = $2)`,
    [uid, name]);
}

const tags = ['General', 'Design', 'Product', 'Focus', 'Build', 'Care'];
const folders = ['Stress', 'Stress Archive', 'Productivity'];
const mkTasks = (n, status, off) =>
  Array.from({ length: n }, (_, i) => {
    const k = off + i + 1;
    return [
      `STRESS-${String(k).padStart(4, '0')} ${status} task with a reasonably long title to stress text layout`,
      tags[k % tags.length],
      status,
      folders[k % folders.length],
      status === 'done',
    ];
  });
const all = [
  ...mkTasks(N_TODO, 'todo', 0),
  ...mkTasks(N_PROG, 'in_progress', N_TODO),
  ...mkTasks(N_DONE, 'done', N_TODO + N_PROG),
];
// Bulk insert in chunks, RETURNING ids for the subtask pass.
const ids = [];
for (let i = 0; i < all.length; i += 200) {
  const chunk = all.slice(i, i + 200);
  const vals = [];
  const ph = chunk
    .map((t, j) => {
      const b = j * 5;
      vals.push(t[0], t[1], t[2], t[3], t[4] ? new Date() : null);
      return `($${b + 1}, $${b + 2}, $${b + 3}, $${b + 4}, $${b + 5}, '${uid}')`;
    })
    .join(',');
  // NOTE: completed_at only for done rows; others NULL.
  const res = await pool.query(
    `INSERT INTO tasks (title, tag, status, folder, completed_at, user_id)
     VALUES ${ph} RETURNING id`,
    vals);
  ids.push(...res.rows.map((r) => r.id));
}
let subCount = 0;
for (let i = 0; i < Math.min(N_SUB_TASKS, ids.length); i++) {
  const flat = [];
  for (let s = 0; s < N_SUBS_EACH; s++) {
    flat.push(ids[i], `STRESS sub ${s + 1} of task ${i + 1}`, s === 0);
  }
  const ph2 = Array.from(
    { length: N_SUBS_EACH },
    (_, s) => `($${s * 3 + 1}, $${s * 3 + 2}, $${s * 3 + 3})`).join(',');
  await pool.query(
    `INSERT INTO subtasks (task_id, title, done) VALUES ${ph2}`,
    flat);
  subCount += N_SUBS_EACH;
}
const ms = Date.now() - t0;
console.log(JSON.stringify({
  email,
  scale,
  tasksInserted: ids.length,
  subtasksInserted: subCount,
  ms,
}));
await pool.end();
