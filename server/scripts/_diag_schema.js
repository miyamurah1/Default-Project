// Temporary read-only diagnostic: dump the live schema for seed-relevant tables.
import pg from 'pg';
const pool = new pg.Pool({
  connectionString:
    'postgres://bloom:bloom_dev_password@localhost:5433/daily_bloom',
});
const TABLES = [
  'users', 'user_tokens', 'owned_themes', 'themes',
  'tasks', 'subtasks', 'contributions', 'folders', 'rules',
];
for (const t of TABLES) {
  const { rows } = await pool.query(
    `SELECT column_name, data_type, is_nullable, column_default
       FROM information_schema.columns
      WHERE table_schema='public' AND table_name=$1
      ORDER BY ordinal_position`,
    [t],
  );
  console.log(`\n=== ${t} (${rows.length} cols) ===`);
  if (!rows.length) console.log('  <table does not exist>');
  for (const c of rows) {
    console.log(
      `  ${c.column_name} ${c.data_type} ${c.is_nullable === 'NO' ? 'NOT NULL' : ''} ${c.column_default ? '= ' + c.column_default : ''}`,
    );
  }
}
await pool.end();