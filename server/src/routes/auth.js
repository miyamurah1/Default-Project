// Firebase Auth routes. Moved verbatim from src/index.js (route split).
// No logic changes.
import { getAuth } from 'firebase-admin/auth';

export function registerAuthRoutes(app, { pool, requireAuth, publicUser, authLimiter }) {
// --- Firebase Auth routes ---

/**
 * POST /api/auth/firebase-sync
 * Called by the Flutter app after every Firebase sign-in (email/password or
 * Google). Verifies the Firebase ID token, then upserts the DB user row.
 * Returns the enriched DB profile so the app gets avatar_label, active_theme, etc.
 */
app.post('/api/auth/firebase-sync', authLimiter, async (req, res) => {
  const header = req.headers.authorization || '';
  const [scheme, idToken] = header.split(' ');
  if (scheme !== 'Bearer' || !idToken) {
    return res.status(401).json({ error: 'authentication required' });
  }
  try {
    const decoded = await getAuth().verifyIdToken(idToken);
    const uid = decoded.uid;
    const email = (decoded.email ?? req.body?.email ?? '').toLowerCase().trim();
    const displayName = String(
      req.body?.display_name ||
      decoded.name ||
      email.split('@')[0]
    ).trim().slice(0, 60);

    // Upsert: find by firebase_uid or email (for accounts that existed
    // before Firebase migration), then update firebase_uid column.
    const { rows: existing } = await pool.query(
      `SELECT * FROM users WHERE firebase_uid = $1 OR lower(email) = $2 LIMIT 1`,
      [uid, email],
    );

    let user;
    if (existing.length) {
      // Existing account — update firebase_uid if not set yet (migration).
      const row = existing[0];
      if (!row.firebase_uid) {
        await pool.query(
          'UPDATE users SET firebase_uid = $1 WHERE id = $2',
          [uid, row.id],
        );
      }
      user = publicUser({ ...row, firebase_uid: uid });
    } else {
      // Brand-new account — create DB row and seed defaults.
      const { rows } = await pool.query(
        `INSERT INTO users (firebase_uid, email, display_name)
         VALUES ($1, $2, $3) RETURNING *`,
        [uid, email, displayName],
      );
      user = publicUser(rows[0]);
      // Seed: 450 starting tokens, free baseline themes, one automation rule.
      try {
        await pool.query(
          'INSERT INTO user_tokens (user_id, balance) VALUES ($1, 450)',
          [user.id]);
        await pool.query(
          'INSERT INTO owned_themes (user_id, theme_id) VALUES ($1, $2)',
          [user.id, 'edo']);
        await pool.query(
          'INSERT INTO owned_themes (user_id, theme_id) VALUES ($1, $2)',
          [user.id, 'midnight']);
        await pool.query(
          `INSERT INTO rules (user_id, name, trigger, condition, actions)
           VALUES ($1, 'Done → +10 tokens', 'task_done', '{}', $2)`,
          [user.id, JSON.stringify([{ type: 'award_tokens', amount: 10 }])]);
      } catch (e) {
        console.error('[auth] seed failed:', e?.code ?? e);
      }
      res.status(201).json({ user });
      return;
    }
    res.json({ user });
  } catch (e) {
    console.error('[auth] firebase-sync failed:', e?.code ?? e?.message);
    res.status(401).json({ error: 'invalid or expired Firebase token' });
  }
});

/**
 * GET /api/auth/me
 * Returns the current user's DB profile. Requires a valid Firebase ID token.
 */
app.get('/api/auth/me', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM users WHERE id = $1', [req.userId]);
    if (!rows.length) return res.status(401).json({ error: 'account not found' });
    res.json({ user: publicUser(rows[0]) });
  } catch {
    res.status(500).json({ error: 'could not load profile' });
  }
});

/**
 * DELETE /api/auth/account
 * Deletes the backend DB row. The Flutter client separately calls
 * FirebaseAuth.currentUser.delete() to remove the Firebase identity.
 * (Play Store requirement: full data deletion on account removal.)
 */
app.delete('/api/auth/account', requireAuth, async (req, res) => {
  try {
    // Also delete Firebase Auth user so the UID is fully gone.
    if (req.firebaseUid) {
      try {
        await getAuth().deleteUser(req.firebaseUid);
      } catch (e) {
        // Non-fatal: DB row deletion is the critical part.
        console.warn('[auth] Firebase user delete failed:', e?.code);
      }
    }
    await pool.query('DELETE FROM users WHERE id = $1', [req.userId]);
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: 'could not delete account' });
  }
});

// Logout is now stateless — Firebase handles token invalidation.
// This endpoint exists for compatibility / server-side audit logging.
app.post('/api/auth/logout', async (req, res) => {
  res.json({ ok: true });
});
}