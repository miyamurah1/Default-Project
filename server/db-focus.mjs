// focus_sessions columns (the /api/export route queries user_id here)
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
const r = await pool.query(
  `SELECT column_name, data_type, is_nullable FROM information_schema.columns
   WHERE table_name='focus_sessions' ORDER BY ordinal_position`
);
console.log('focus_sessions columns:');
for (const x of r.rows) console.log('  ' + x.column_name, x.data_type, x.is_nullable);
const c = await pool.query('SELECT COUNT(*) n FROM focus_sessions');
console.log('focus_sessions rows:', c.rows[0].n);
await pool.end();
