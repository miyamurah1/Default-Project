// Reproduce the folders auto-create ON CONFLICT from registerTaskRoutes.
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
(async () => {
  try {
    await pool.query(
      'INSERT INTO folders (name, icon, user_id) VALUES ($1, $2, $3) ON CONFLICT (user_id, name) DO NOTHING',
      ['Productivity', 'folder', '00000000-0000-0000-0000-000000000000']
    );
    console.log('folders INSERT OK');
  } catch (e) {
    console.error('folders INSERT ERROR:', e.code ?? e.message, ' | ', e.detail ?? '');
  }
  const c = await pool.query("SELECT conname, pg_get_constraintdef(conrelid) FROM pg_constraint WHERE conrelid = 'folders'::regclass");
  console.log('folders constraints:');
  for (const r of c.rows) console.log('  ' + r.conname + ': ' + r.pg_get_constraintdef);
  await pool.end();
})().catch((e) => { console.error('ERR', e); process.exit(1); });
