// Reproduce the route's exact DB write sequence (folders then tasks), with a REAL user id.
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
(async () => {
  const u = await pool.query('SELECT id FROM users ORDER BY id LIMIT 1');
  const uid = u.rows[0].id;
  console.log('user id:', uid);
  try {
    await pool.query('INSERT INTO folders (name, icon, user_id) VALUES ($1, $2, $3) ON CONFLICT (user_id, name) DO NOTHING', ['Productivity', 'folder', uid]);
    console.log('folders INSERT OK');
  } catch (e) {
    console.error('folders INSERT ERROR:', e.code ?? e.message, ' | ', e.detail ?? '');
  }
  try {
    const { rows } = await pool.query(
      `INSERT INTO tasks (title, tag, status, folder, avatar_label, description, priority, recurring, position, due_at, user_id, client_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      ['Batch probe one', 'ZZZQ', 'todo', 'Productivity', '禅', '', 'none', 'none', 0, null, uid, null]);
    console.log('tasks INSERT OK:', rows[0].id);
  } catch (e) {
    console.error('tasks INSERT ERROR:', e.code ?? e.message, ' | ', e.detail ?? '');
  }
  await pool.end();
})().catch((e) => { console.error('ERR', e); process.exit(1); });
