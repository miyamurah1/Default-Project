// List folders indexes/constraints (verify ON CONFLICT (user_id, name) target exists)
import pg from 'pg';
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
const r = await pool.query("SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'folders' ORDER BY indexname");
console.log('folders indexes:');
for (const x of r.rows) console.log(x.indexname, '::', x.indexdef);
// Also show the raw columns so we can map the FK
const cols = await pool.query("SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name='folders' ORDER BY ordinal_position");
console.log('folders columns:');
for (const x of cols.rows) console.log('  ' + x.column_name, x.data_type, x.is_nullable);
await pool.end();
