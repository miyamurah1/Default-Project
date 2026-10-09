// Flow rules. Moved verbatim from src/index.js.

export function registerRuleRoutes(app, { pool, requireAuth, validRuleBody }) {
// --- Flows: rules, run log, wallet, inbox ---

app.get('/api/rules', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM rules WHERE user_id = $1 ORDER BY created_at', [req.userId]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load flows' });
  }
});

app.post('/api/rules', requireAuth, async (req, res) => {
  try {
    const { name = '', trigger, condition = {}, actions = [] } = req.body ?? {};
    if (!String(name).trim()) return res.status(400).json({ error: 'name your flow' });
    const problem = validRuleBody({ trigger, condition, actions });
    if (problem) return res.status(400).json({ error: problem });
    const { rows } = await pool.query(
      `INSERT INTO rules (user_id, name, trigger, condition, actions)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.userId, String(name).trim().slice(0, 80), trigger,
       JSON.stringify(condition), JSON.stringify(actions)],
    );
    res.status(201).json(rows[0]);
  } catch {
    res.status(500).json({ error: 'could not save flow' });
  }
});

app.patch('/api/rules/:id', requireAuth, async (req, res) => {
  try {
    const { rows: own } = await pool.query(
      'SELECT * FROM rules WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!own.length) return res.status(404).json({ error: 'not found' });
    const cur = own[0];
    const next = {
      name: req.body?.name ?? cur.name,
      enabled: req.body?.enabled ?? cur.enabled,
      trigger: req.body?.trigger ?? cur.trigger,
      condition: req.body?.condition ?? cur.condition,
      actions: req.body?.actions ?? cur.actions,
    };
    if (!String(next.name).trim()) return res.status(400).json({ error: 'name your flow' });
    const problem = validRuleBody(next);
    if (problem) return res.status(400).json({ error: problem });
    const { rows } = await pool.query(
      `UPDATE rules SET name = $3, enabled = $4, trigger = $5,
         condition = $6, actions = $7
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      [req.params.id, req.userId, String(next.name).trim().slice(0, 80),
       next.enabled, next.trigger,
       JSON.stringify(next.condition), JSON.stringify(next.actions)],
    );
    res.json(rows[0]);
  } catch {
    res.status(500).json({ error: 'could not update flow' });
  }
});

app.delete('/api/rules/:id', requireAuth, async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM rules WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!rowCount) return res.status(404).json({ error: 'not found' });
    res.status(204).end();
  } catch {
    res.status(500).json({ error: 'could not delete flow' });
  }
});

app.get('/api/rules/:id/runs', requireAuth, async (req, res) => {
  try {
    const { rows: own } = await pool.query(
      'SELECT id FROM rules WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!own.length) return res.status(404).json({ error: 'not found' });
    const limit = Math.min(parseInt(req.query.limit ?? '50', 10) || 50, 200);
    const { rows } = await pool.query(
      `SELECT * FROM rule_runs WHERE rule_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [req.params.id, limit]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load runs' });
  }
});
}