// Folders. Moved verbatim from src/index.js.

export function registerFolderRoutes(app, { pool, requireAuth }) {
// Folders are addressed by name in this app.
// Allows specifying fallback (e.g. ?fallback=Productivity) to reassign remaining tasks,
// preventing deadlocks!
app.delete('/api/folders/:name', requireAuth, async (req, res) => {
  try {
    const name = req.params.name;
    const fallback = req.query.fallback ? String(req.query.fallback).trim() : null;
    if (fallback) {
      await pool.query(
        'INSERT INTO folders (name, icon, user_id) VALUES ($1, $2, $3) ON CONFLICT (user_id, name) DO NOTHING',
        [fallback, 'folder', req.userId]
      );
      await pool.query(
        'UPDATE tasks SET folder = $1 WHERE folder = $2 AND user_id = $3',
        [fallback, name, req.userId]
      );
    } else {
      const { rows: kids } = await pool.query(
        'SELECT id FROM tasks WHERE folder = $1 AND user_id = $2 LIMIT 1',
        [name, req.userId]);
      if (kids.length) {
        return res.status(400).json({ error: 'move its tasks out first or specify ?fallback=folder' });
      }
    }
    const { rowCount } = await pool.query(
      'DELETE FROM folders WHERE name = $1 AND user_id = $2', [name, req.userId]);
    if (!rowCount) return res.status(404).json({ error: 'not found' });
    res.status(204).end();
  } catch {
    res.status(500).json({ error: 'could not delete folder' });
  }
});

// Rename folder and cascade name update to its tasks
app.patch('/api/folders/:name', requireAuth, async (req, res) => {
  try {
    const oldName = req.params.name;
    const newName = String(req.body?.name ?? '').trim().slice(0, 80);
    if (!newName) return res.status(400).json({ error: 'name required' });
    const { rows } = await pool.query(
      'UPDATE folders SET name = $1 WHERE name = $2 AND user_id = $3 RETURNING *',
      [newName, oldName, req.userId]
    );
    if (!rows.length) return res.status(404).json({ error: 'folder not found' });
    await pool.query(
      'UPDATE tasks SET folder = $1 WHERE folder = $2 AND user_id = $3',
      [newName, oldName, req.userId]
    );
    res.json(rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'folder with that name already exists' });
    res.status(500).json({ error: 'could not rename folder' });
  }
});
// Folders with live task counts
app.get('/api/folders', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT f.name, f.icon,
              COUNT(t.id)::int AS total,
              COUNT(t.id) FILTER (WHERE t.status = 'done')::int AS completed
       FROM folders f LEFT JOIN tasks t ON t.folder = f.name AND t.user_id = f.user_id
       WHERE f.user_id = $1
       GROUP BY f.name, f.icon, f.created_at ORDER BY f.created_at`, [req.userId]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load folders' });
  }
});

app.post('/api/folders', requireAuth, async (req, res) => {
  const { name, icon = 'folder' } = req.body;
  if (!name || !name.trim()) return res.status(400).json({ error: 'name required' });
  try {
    const { rows } = await pool.query(
      `INSERT INTO folders (user_id, name, icon) VALUES ($1, $2, $3) RETURNING *`,
      [req.userId, name.trim(), icon],
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'folder exists' });
    console.error('[folders] create failed:', e?.code ?? e);
    return res.status(500).json({ error: 'could not create folder' });
  }
});

}