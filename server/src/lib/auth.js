// Firebase Auth middleware. Moved verbatim from src/index.js
// (route split) â€” wrapped in a pool factory. No logic changes.
import { getAuth } from 'firebase-admin/auth';

export const publicUser = (row) => ({
  id: row.id,
  uid: row.firebase_uid ?? row.uid ?? row.id,
  email: row.email,
  display_name: row.display_name ?? '',
  avatar_label: row.avatar_label ?? '禅',
  active_theme: row.active_theme ?? 'edo',
  created_at: row.created_at,
});

export function createRequireAuth(pool) {
const testBypass =
  process.env.NODE_ENV === 'test' ? process.env.TEST_BYPASS_TOKEN : null;

async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, idToken] = header.split(' ');
  if (scheme !== 'Bearer' || !idToken) {
    return res.status(401).json({ error: 'authentication required' });
  }
  if (testBypass && idToken.startsWith(testBypass + ':')) {
    const testEmail = idToken
      .slice(testBypass.length + 1)
      .toLowerCase()
      .trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(testEmail)) {
      return res.status(401).json({ error: 'authentication required' });
    }
    try {
      const uid = 'test:' + testEmail;
      let rows = (
        await pool.query('SELECT id FROM users WHERE firebase_uid = $1', [uid])
      ).rows;
      if (!rows.length) {
        const created = (
          await pool.query(
            `INSERT INTO users (firebase_uid, email, display_name)
             VALUES ($1, $2, $3) RETURNING id`,
            [uid, testEmail, testEmail.split('@')[0]],
          )
        ).rows;
        rows = created;
        const newId = created[0].id;
        await pool.query(
          'INSERT INTO user_tokens (user_id, balance) VALUES ($1, 450)',
          [newId],
        );
        await pool.query(
          'INSERT INTO owned_themes (user_id, theme_id) VALUES ($1, $2)',
          [newId, 'edo'],
        );
        await pool.query(
          'INSERT INTO owned_themes (user_id, theme_id) VALUES ($1, $2)',
          [newId, 'midnight'],
        );
        await pool.query(
          `INSERT INTO rules (user_id, name, trigger, condition, actions)
           VALUES ($1, 'Done → +10 tokens', 'task_done', '{}', $2)`,
          [newId, JSON.stringify([{ type: 'award_tokens', amount: 10 }])],
        );
      }
      req.userId = rows[0].id;
      req.firebaseUid = uid;
      return next();
    } catch (e) {
      console.error('[auth] test bypass failed:', e?.code ?? e);
      return res.status(500).json({ error: 'test sign-in failed' });
    }
  }
  try {
    const decoded = await getAuth().verifyIdToken(idToken);
    req.firebaseUid = decoded.uid;
    // Look up the DB user row by firebase_uid.
    const { rows } = await pool.query(
      'SELECT id FROM users WHERE firebase_uid = $1',
      [decoded.uid],
    );
    if (!rows.length) {
      return res.status(401).json({ error: 'account not found — please sign in again' });
    }
    req.userId = rows[0].id;
    next();
  } catch (e) {
    console.error('[auth] token verification failed:', e?.code ?? e?.message);
    return res.status(401).json({ error: 'session expired — please log in again' });
  }
}
  return requireAuth;
}