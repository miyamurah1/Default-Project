// List users table columns (id type must match tasks.user_id uuid)
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
const r = await pool.query(
  `SELECT column_name, data_type FROM information_schema.columns
   WHERE table_name='users' ORDER BY ordinal_position`
);
console.log('USERS COLUMNS:');
for (const x of r.rows) console.log('  ' + x.column_name + ' : ' + x.data_type);
await pool.end();
