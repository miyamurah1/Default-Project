import pg from 'pg';
const pool = new pg.Pool({
  connectionString:
    'postgres://bloom:bloom_dev_password@localhost:5433/daily_bloom',
});
const rows = await pool.query(
  `SELECT t.id, u.email, t.status,
          length(t.title) AS title_len,
          left(t.title, 80) AS title_head,
          t.title IS NULL AS title_null,
          (SELECT count(*) FROM subtasks s WHERE s.task_id = t.id) AS subs,
          t.created_at
   FROM tasks t JOIN users u ON u.id = t.user_id
   ORDER BY u.email, t.created_at DESC NULLS LAST`);
console.log(JSON.stringify(rows.rows, null, 1));
await pool.end();
