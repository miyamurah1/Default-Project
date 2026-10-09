// Reproduce the tasks INSERT the POST /api/tasks route executes, with a real user_id.
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
(async () => {
  const u = await pool.query('SELECT id FROM users ORDER BY id LIMIT 1');
  const uid = u.rows[0].id;
  console.log('user id:', uid);
  const params = ['Batch probe one', 'ZZZQ', 'todo', 'Productivity', '禅', '', 'none', 'none', 0, null, uid, null];
  const cols = '(title, tag, status, folder, avatar_label, description, priority, recurring, position, due_at, user_id, client_id)';
  const sql = `INSERT INTO tasks ${cols} VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`;
  try {
    const r = await pool.query(sql, params);
    console.log('INSERT OK:', JSON.stringify(r.rows[0]));
  } catch (e) {
    console.error('INSERT ERROR:', e.code ?? e.message, ' | ', e.detail ?? '');
  }
  await pool.end();
})().catch((e) => { console.error('ERR', e); process.exit(1); });
