// Temporary read-only diagnostic: dump the users table.
import pg from 'pg';
const pool = new pg.Pool({
  connectionString:
    'postgres://bloom:bloom_dev_password@localhost:5433/daily_bloom',
});
try {
  const { rows } = await pool.query(
    'SELECT id, email, firebase_uid, display_name, active_theme FROM users ORDER BY id',
  );
  console.log('USERS:', rows.length);
  console.table(rows);
} catch (e) {
  console.log('DB ERR:', e.message);
}
await pool.end();