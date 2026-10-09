// DB schema/data probe
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
(async () => {
  const tables = await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name");
  console.log('DB:TABLES:', JSON.stringify(tables.rows.map((x) => x.table_name)));
  const tasks = await pool.query('SELECT COUNT(*) AS n FROM tasks');
  console.log('DB:tasks rows:', tasks.rows[0].n);
  const users = await pool.query('SELECT COUNT(*) AS n FROM "users"');
  console.log('DB:users rows:', users.rows[0].n);
  await pool.end();
})().catch((e) => { console.error('DB ERR', e.message); process.exit(1); });
