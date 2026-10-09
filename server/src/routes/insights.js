// Activity, insights, heatmap, progress. Moved verbatim from src/index.js.

export function registerInsightRoutes(app, { pool, requireAuth, levelFor, streakStats }) {
// Global activity feed, newest first. ?limit= (default 50, max 200).
app.get('/api/activity', requireAuth, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit ?? '50', 10) || 50, 200);
    const { rows } = await pool.query(
      `SELECT e.*, t.title AS task_title
       FROM task_events e JOIN tasks t ON t.id = e.task_id
       WHERE t.user_id = $1
       ORDER BY e.created_at DESC LIMIT $2`, [req.userId, limit]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load activity' });
  }
});

// Phase D — personal feedback feed. One batched response; the app
// turns these numbers into plain-language insights (backend stays dumb).
app.get('/api/insights', requireAuth, async (req, res) => {
  try {
    const { rows: byTag } = await pool.query(
      `SELECT tag, COUNT(*)::int AS total,
              COUNT(*) FILTER (WHERE status = 'done')::int AS done
       FROM tasks WHERE user_id = $1 GROUP BY tag ORDER BY total DESC LIMIT 8`,
      [req.userId]);
    const { rows: byFolder } = await pool.query(
      `SELECT folder, COUNT(*)::int AS total,
              COUNT(*) FILTER (WHERE status = 'done')::int AS done
       FROM tasks WHERE user_id = $1 GROUP BY folder ORDER BY total DESC LIMIT 8`,
      [req.userId]);
    const { rows: cycle } = await pool.query(
      `SELECT COUNT(*)::int AS n,
              COALESCE(AVG(EXTRACT(EPOCH FROM (completed_at - created_at)) / 3600), 0)::float AS avg_hours,
              COALESCE(PERCENTILE_CONT(0.5) WITHIN GROUP
                (ORDER BY EXTRACT(EPOCH FROM (completed_at - created_at)) / 3600), 0)::float AS median_hours
       FROM tasks
       WHERE user_id = $1 AND status = 'done' AND completed_at >= now() - INTERVAL '30 days'`,
      [req.userId]);
    const { rows: hours } = await pool.query(
      `SELECT EXTRACT(HOUR FROM completed_at AT TIME ZONE 'UTC')::int AS h,
              COUNT(*)::int AS n
       FROM tasks
       WHERE user_id = $1 AND status = 'done' AND completed_at >= now() - INTERVAL '30 days'
       GROUP BY 1 ORDER BY 1`,
      [req.userId]);
    const { rows: focus } = await pool.query(
      `SELECT COALESCE(SUM(actual_minutes), 0)::int AS minutes,
              COUNT(*)::int AS sessions
       FROM focus_sessions
       WHERE user_id = $1 AND started_at >= now() - INTERVAL '7 days'`,
      [req.userId]);
    const { rows: focusDays } = await pool.query(
      `SELECT (started_at AT TIME ZONE 'UTC')::date::text AS date,
              COALESCE(SUM(actual_minutes), 0)::int AS minutes
       FROM focus_sessions
       WHERE user_id = $1 AND started_at >= now() - INTERVAL '6 days'
       GROUP BY 1 ORDER BY 1`, [req.userId]);
    const { rows: contrib } = await pool.query(
      `SELECT day::text AS date, count FROM contributions
       WHERE user_id = $1 AND day >= CURRENT_DATE - INTERVAL '29 days' ORDER BY day`,
      [req.userId]);
    const { best, cur } = streakStats(contrib, 30);
    res.json({
      byTag, byFolder,
      cycle: cycle[0],
      hours,
      focus7: focus[0],
      focusDays,
      streak: { best30: best, current: cur },
    });
  } catch {
    res.status(500).json({ error: 'could not load insights' });
  }
});
// GitHub-style heatmap: last N weeks of day -> count -> level
app.get('/api/heatmap', requireAuth, async (req, res) => {
  try {
    const weeks = Math.min(parseInt(req.query.weeks ?? '12', 10) || 12, 52);
    const days = weeks * 7;
    const { rows } = await pool.query(
      `SELECT day::text AS date, count FROM contributions
       WHERE user_id = $1 AND day >= CURRENT_DATE - ($2 || ' days')::interval
       ORDER BY day`,
      [req.userId, days - 1],
    );
    res.json(rows.map((r) => ({ ...r, level: levelFor(r.count) })));
  } catch {
    res.status(500).json({ error: 'could not load heatmap' });
  }
});

// Progress summary: counts per status + real streaks (like git).
// bestStreak = longest run of days with count>0 in last year.
// currentStreak = run ending today (or yesterday if today is 0).
app.get('/api/progress', requireAuth, async (req, res) => {
  try {
    const { rows: byStatus } = await pool.query(
      `SELECT status, COUNT(*)::int AS n FROM tasks WHERE user_id = $1 GROUP BY status`,
      [req.userId],
    );
    const { rows: streak } = await pool.query(
      `SELECT COUNT(*)::int AS active_days,
              COALESCE(SUM(count),0)::int AS total
       FROM contributions WHERE user_id = $1 AND day >= CURRENT_DATE - INTERVAL '29 days'`,
      [req.userId],
    );
    const { rows: days } = await pool.query(
      `SELECT day::text AS date, count FROM contributions
       WHERE user_id = $1 AND day >= CURRENT_DATE - INTERVAL '364 days'
       ORDER BY day`,
      [req.userId],
    );
    const { best, cur } = streakStats(days, 365);
    res.json({ byStatus, ...streak[0], bestStreak: best, currentStreak: cur });
  } catch {
    res.status(500).json({ error: 'could not load progress' });
  }
});
}