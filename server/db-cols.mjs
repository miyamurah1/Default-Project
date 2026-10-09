// List tasks table columns
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
const r = await pool.query(
  `SELECT column_name, data_type FROM information_schema.columns
   WHERE table_name='tasks' ORDER BY ordinal_position`
);
console.log('TASKS COLUMNS:');
for (const x of r.rows) console.log('  ' + x.column_name + ' : ' + x.data_type);
const c = await pool.query('SELECT COUNT(*) n FROM tasks');
console.log('tasks rows:', c.rows[0].n);
await pool.end();
