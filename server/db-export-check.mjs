// Columns of the tables /api/export queries (inbox_messages, user_tokens, rules, folders, focus_sessions)
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
const tables = ['inbox_messages', 'user_tokens', 'rules', 'folders', 'focus_sessions', 'tasks', 'users'];
(async () => {
  for (const t of tables) {
    const cols = await pool.query(
      `SELECT column_name FROM information_schema.columns WHERE table_name = $1 ORDER BY ordinal_position`,
      [t]);
    console.log(t + ':', cols.rows.map(r => r.column_name).join(', '));
  }
  await pool.end();
})().catch((e) => { console.error('ERR', e); process.exit(1); });
