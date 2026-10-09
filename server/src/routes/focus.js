// Focus timer. Moved verbatim from src/index.js.

export function registerFocusRoutes(app, { pool, requireAuth, logEvent, runRules }) {
// --- Phase B: focus timer ---

// Start a timer on a task — or free ("Free Deep Work") when task_id
// is omitted. Free sessions still count minutes + heatmap on finish.
app.post('/api/focus', requireAuth, async (req, res) => {
  try {
    const minutes = Math.max(1, Math.min(180, parseInt(req.body?.minutes ?? 25, 10) || 25));
    const mode = req.body?.mode === 'break' ? 'break' : 'focus';
    const taskId = req.body?.task_id ?? null;
    if (taskId != null) {
      const { rows: task } = await pool.query(
        'SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [taskId, req.userId]);
      if (!task.length) return res.status(404).json({ error: 'task not found' });
    }
    const { rows } = await pool.query(
      `INSERT INTO focus_sessions (task_id, user_id, mode, planned_minutes)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [taskId, req.userId, mode, minutes]);
    res.status(201).json(rows[0]);
  } catch {
    res.status(500).json({ error: 'could not start focus' });
  }
});

// Finish (completed=true) or abandon a session. Finishing a focus
// session bumps the heatmap like a commit and fires flows.
app.patch('/api/focus/:id', requireAuth, async (req, res) => {
  try {
    const completed = req.body?.completed === true;
    const actual = Math.max(0, Math.min(480, parseInt(req.body?.actual_minutes ?? 0, 10) || 0));
    const subtask = String(req.body?.subtask ?? '').trim().slice(0, 200);
    const { rows } = await pool.query(
      `UPDATE focus_sessions SET completed = $2, actual_minutes = $3, ended_at = now()
       WHERE id = $1 AND user_id = $4 RETURNING *`,
      [req.params.id, completed, actual, req.userId]);
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    const s = rows[0];
    if (completed && s.mode === 'focus') {
      // FIX: contributions is per-user, so the write must carry
      // user_id — this used to insert a user-less row (and collide
      // with every other user under ON CONFLICT (day)), so the
      // per-user reads in /api/heatmap, /api/progress and
      // /api/insights (all "WHERE user_id = $1") never saw it.
      await pool.query(
        `INSERT INTO contributions (user_id, day, count) VALUES ($1, CURRENT_DATE, 1)
         ON CONFLICT (user_id, day) DO UPDATE SET count = contributions.count + 1`,
        [req.userId]);
      const { rows: parent } = await pool.query('SELECT * FROM tasks WHERE id = $1', [s.task_id]);
      if (parent.length) {
        await logEvent(pool, parent[0].id, req.userId, 'note',
          { body: subtask
              ? `Focused ${s.planned_minutes} min on "${subtask}"`
              : `Focused ${s.planned_minutes} min` });
        await runRules(pool, 'focus_done', parent[0], req.userId);
      }
    }
    res.json(s);
  } catch {
    res.status(500).json({ error: 'could not finish focus' });
  }
});

// History + totals for one task.
app.get('/api/tasks/:id/focus', requireAuth, async (req, res) => {
  try {
    const { rows: own } = await pool.query(
      'SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!own.length) return res.status(404).json({ error: 'not found' });
    const { rows } = await pool.query(
      'SELECT * FROM focus_sessions WHERE task_id = $1 ORDER BY started_at DESC LIMIT 50',
      [req.params.id]);
    const { rows: tot } = await pool.query(
      `SELECT COUNT(*)::int AS sessions,
              COALESCE(SUM(actual_minutes),0)::int AS minutes,
              COALESCE(SUM(CASE WHEN completed THEN 1 ELSE 0 END),0)::int AS completed
       FROM focus_sessions WHERE task_id = $1`, [req.params.id]);
    res.json({ sessions: rows, totals: tot[0] });
  } catch {
    res.status(500).json({ error: 'could not load focus history' });
  }
});

// Minutes per day for the last N days (Phase D insights feed).
app.get('/api/focus/summary', requireAuth, async (req, res) => {
  try {
    const days = Math.min(parseInt(req.query.days ?? '7', 10) || 7, 90);
    const { rows } = await pool.query(
      `SELECT (started_at AT TIME ZONE 'UTC')::date::text AS date,
              COALESCE(SUM(actual_minutes),0)::int AS minutes,
              COUNT(*)::int AS sessions
       FROM focus_sessions
       WHERE user_id = $1 AND started_at >= now() - ($2 || ' days')::interval
       GROUP BY 1 ORDER BY 1`, [req.userId, days]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load summary' });
  }
});
}