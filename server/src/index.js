import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import pg from 'pg';
import rateLimit from 'express-rate-limit';
import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

// ── Firebase Admin initialisation (modular SDK — no default-import
// interop quirks) ─────────────────────────────────────────────────────────
// Credential sources, in order:
//  1. FIREBASE_SERVICE_ACCOUNT — the JSON itself (Render/Railway secrets).
//  2. GOOGLE_APPLICATION_CREDENTIALS — path to the service-account file
//     (local .env: ./firebase-service-account.json).
//  3. Application Default Credentials (Google Cloud / Cloud Run).
// Without one of these, verifyIdToken() rejects every token and the app
// sits in offline mode with firebase-sync 401s — Firebase login itself
// still succeeds, which is exactly the confusing split in the web log.
let firebaseReady = false;
let firebaseCredentialSource = 'application-default';
try {
  const saJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  let credential = null;
  if (saJson) {
    credential = cert(JSON.parse(saJson));
    firebaseCredentialSource = 'env-json';
  } else if (saPath) {
    const { readFileSync } = await import('node:fs');
    const { resolve, isAbsolute, dirname } = await import('node:path');
    const { fileURLToPath } = await import('node:url');
    const here = dirname(fileURLToPath(import.meta.url));
    const abs = isAbsolute(saPath) ? saPath : resolve(here, '..', saPath);
    credential = cert(JSON.parse(readFileSync(abs, 'utf8')));
    firebaseCredentialSource = 'file:' + abs;
  } else {
    credential = applicationDefault();
  }
  initializeApp({ credential });
  firebaseReady = true;
  console.log(
    '[firebase] Admin SDK initialised via ' + firebaseCredentialSource,
  );
} catch (e) {
  console.error('[firebase] Admin SDK init failed — auth will not work:', e?.message ?? e);
}

const { Pool } = pg;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const app = express();
app.use(cors());
app.use(express.json());

// JWT_SECRET is no longer used — Firebase ID tokens are the auth mechanism.
// bcrypt is no longer needed either (Firebase manages passwords).

// Launch hardening: slow down password guessing. 30 tries per 15 min
// per IP on the two credential endpoints; honest users never notice.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: 'too many attempts — try again in a few minutes' },
});

// Flood guard for every write endpoint (rules/notes/subtasks/focus
// could otherwise be script-spammed). Reads stay unlimited.
const writeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: 'too many writes — slow down a little' },
});
app.use((req, res, next) => {
  if (req.method === 'POST' || req.method === 'PATCH' || req.method === 'DELETE') {
    return writeLimiter(req, res, next);
  }
  next();
});

// --- Auth helpers ---

const publicUser = (row) => ({
  id: row.id,
  uid: row.firebase_uid ?? row.uid ?? row.id,
  email: row.email,
  display_name: row.display_name ?? '',
  avatar_label: row.avatar_label ?? '禅',
  active_theme: row.active_theme ?? 'edo',
  created_at: row.created_at,
});

/**
 * requireAuth — verifies a Firebase ID token in the Authorization header.
 * Sets req.userId (DB integer PK) and req.firebaseUid (Firebase UID string).
 */
// Test-only auth bypass: `npm test` cannot mint real Firebase ID tokens,
// so when (AND ONLY when) NODE_ENV=test and TEST_BYPASS_TOKEN is set,
// `Bearer <TEST_BYPASS_TOKEN>:<email>` signs in as a throwaway test user
// (row auto-created with firebase_uid `test:<email>`, same seeds as
// firebase-sync). Production never sets these vars: hatch stays closed.
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

const levelFor = (count) => {
  if (count >= 5) return 5;
  if (count >= 4) return 4;
  if (count >= 3) return 3;
  if (count >= 2) return 2;
  if (count >= 1) return 1;
  return 0;
};

// Shared streak math (progress + insights): best = longest run of
// active days in the window; cur = run ending today (or yesterday
// when today is still empty). Gaps (missing rows) break the run.
function streakStats(dayCounts, windowDays) {
  const byDate = new Map(dayCounts.map((d) => [d.date, d.count]));
  const today = new Date();
  const fmt = (d) => d.toISOString().slice(0, 10);
  let best = 0, run = 0, curRun = 0;
  for (let i = windowDays - 1; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const c = byDate.get(fmt(d)) ?? 0;
    run = c > 0 ? run + 1 : 0;
    if (run > best) best = run;
  }
  for (let i = 0; i < windowDays; i++) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const c = byDate.get(fmt(d)) ?? 0;
    if (i === 0 && c === 0) continue; // today empty -> start from yesterday
    if (c > 0) curRun++;
    else break;
  }
  return { best, cur: curRun };
}

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      ok: true,
      firebaseReady,
      firebaseCredentialSource,
    });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

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

// Append-only history writer. Never throws: a logging failure must not
// fail the user's actual action, so errors are swallowed after a log line.
async function logEvent(taskId, userId, kind, { from = null, to = null, body = '' } = {}) {
  try {
    await pool.query(
      `INSERT INTO task_events (task_id, user_id, kind, from_status, to_status, body)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [taskId, userId ?? null, kind, from, to, body],
    );
  } catch (e) {
    console.error('[history] logEvent failed:', e?.code ?? e);
  }
}

// --- n8n-style flows: rules engine ---
//
// A rule = WHEN trigger + IF condition THEN actions. The visual canvas
// in the app edits exactly this shape, so editor and executor agree.
// Rule-caused writes never re-enter the executor (no infinite loops).

const RULE_TRIGGERS = ['task_created', 'task_moved', 'task_done', 'note_added', 'subtasks_complete', 'focus_done'];
const RULE_ACTIONS = ['award_tokens', 'inbox', 'move_task', 'complete_parent'];

function condMatches(c, task) {
  if (!c || typeof c !== 'object') return true;
  if (Array.isArray(c.all)) return c.all.every((x) => condMatches(x, task));
  if (Array.isArray(c.any)) return c.any.some((x) => condMatches(x, task));
  if (!c.field) return true;
  const val = c.field === 'title' ? (task.title ?? '') : (task[c.field] ?? '');
  if (c.op === 'contains') {
    return String(val).toLowerCase().includes(String(c.value ?? '').toLowerCase());
  }
  return String(val) === String(c.value ?? ''); // default: equals
}

function ruleMatches(rule, task) {
  return condMatches(rule.condition, task);
}

async function runRuleActions(rule, task, userId) {
  const done = [];
  for (const a of rule.actions || []) {
    if (a.type === 'award_tokens') {
      const amount = Math.max(1, Math.min(500, parseInt(a.amount ?? 10, 10) || 10));
      await pool.query(
        `INSERT INTO user_tokens (user_id, balance) VALUES ($1, $2)
         ON CONFLICT (user_id) DO UPDATE SET balance = user_tokens.balance + $2, updated_at = now()`,
        [userId, amount]);
      done.push({ type: 'award_tokens', amount });
    } else if (a.type === 'inbox') {
      await pool.query(
        `INSERT INTO inbox_messages (user_id, tag, title, body) VALUES ($1, $2, $3, $4)`,
        [userId, String(a.tag || 'AUTOMATION').slice(0, 40),
         String(a.title || 'Flow update').slice(0, 200),
         String(a.body || '').slice(0, 1000)]);
      done.push({ type: 'inbox' });
    } else if (a.type === 'move_task') {
      const to = ['todo', 'in_progress', 'done'].includes(a.status) ? a.status : 'done';
      if (task.status !== to) {
        await pool.query('UPDATE tasks SET status = $2 WHERE id = $1', [task.id, to]);
        await logEvent(task.id, userId, 'status',
          { from: task.status, to, body: `via rule ${rule.name}` });
        task.status = to;
      }
      done.push({ type: 'move_task', to });
    } else if (a.type === 'complete_parent') {
      if (task.status !== 'done') {
        await pool.query("UPDATE tasks SET status = 'done' WHERE id = $1", [task.id]);
        await logEvent(task.id, userId, 'status',
          { from: task.status, to: 'done', body: `via rule ${rule.name}` });
        task.status = 'done';
      }
      done.push({ type: 'complete_parent' });
    }
  }
  return done;
}

async function runRules(trigger, task, userId) {
  try {
    const { rows: rules } = await pool.query(
      'SELECT * FROM rules WHERE user_id = $1 AND enabled AND trigger = $2',
      [userId, trigger]);
    for (const rule of rules) {
      try {
        if (!ruleMatches(rule, task)) {
          await pool.query(
            `INSERT INTO rule_runs (rule_id, task_id, task_title, status, detail)
             VALUES ($1, $2, $3, 'skipped', $4)`,
            [rule.id, task.id, task.title ?? '',
             JSON.stringify({ reason: 'condition did not match' })]);
          continue;
        }
        const actions = await runRuleActions(rule, { ...task }, userId);
        await pool.query(
          `INSERT INTO rule_runs (rule_id, task_id, task_title, status, detail)
           VALUES ($1, $2, $3, 'success', $4)`,
          [rule.id, task.id, task.title ?? '', JSON.stringify({ actions })]);
      } catch (e) {
        console.error('[rules] run failed:', e?.code ?? e);
        await pool.query(
          `INSERT INTO rule_runs (rule_id, task_id, task_title, status, detail)
           VALUES ($1, $2, $3, 'failed', $4)`,
          [rule.id, task.id, task.title ?? '',
           JSON.stringify({ error: String(e?.message ?? e) })]);
      }
    }
  } catch (e) {
    console.error('[rules] evaluate failed:', e?.code ?? e);
  }
}

function validCondition(c) {
  if (!c || typeof c !== 'object' || Array.isArray(c)) return 'bad condition';
  if (Array.isArray(c.all)) {
    if (!c.all.length) return 'empty condition group';
    for (const x of c.all) {
      const problem = validCondition(x);
      if (problem) return problem;
    }
    return null;
  }
  if (Array.isArray(c.any)) {
    if (!c.any.length) return 'empty condition group';
    for (const x of c.any) {
      const problem = validCondition(x);
      if (problem) return problem;
    }
    return null;
  }
  if (!c.field) return null; // {} = always
  if (!['tag', 'folder', 'status', 'title'].includes(c.field)) {
    return 'unknown condition field';
  }
  if (c.op && !['equals', 'contains'].includes(c.op)) {
    return 'unknown condition op';
  }
  return null;
}

function validRuleBody(b) {
  if (!b || typeof b !== 'object') return 'invalid rule';
  if (!RULE_TRIGGERS.includes(b.trigger)) return 'unknown trigger';
  if (!Array.isArray(b.actions) || !b.actions.length) return 'add at least one action';
  for (const a of b.actions) {
    if (!a || !RULE_ACTIONS.includes(a.type)) return 'unknown action';
  }
  return validCondition(b.condition ?? {});
}

// --- Existing app routes (now require a valid Bearer token) ---

// Kanban tasks (filterable by status and/or folder)
app.get('/api/tasks', requireAuth, async (req, res) => {
  try {
    const { status, folder } = req.query;
    const conds = ['user_id = $1'];
    const vals = [req.userId];
    if (status) { vals.push(status); conds.push(`status = $${vals.length}`); }
    if (folder) { vals.push(folder); conds.push(`folder = $${vals.length}`); }
    const where = conds.length ? `WHERE ${conds.join(' AND ')}` : '';
    const { rows } = await pool.query(
      `SELECT * FROM tasks ${where} ORDER BY created_at`, vals);
    // Optional embed for the sketch-style card (main task + subtasks
    // below + timer beside): one round trip, no N+1 per card.
    const include = String(req.query.include || '');
    if (include && rows.length) {
      const ids = rows.map((t) => t.id);
      const wantSubs = include.includes('subtasks');
      const wantFocus = include.includes('focus');
      const [subs, focus] = await Promise.all([
        wantSubs
          ? pool.query(
              `SELECT * FROM subtasks WHERE task_id = ANY($1)
               ORDER BY position, created_at`,
              [ids])
          : Promise.resolve({ rows: [] }),
        wantFocus
          ? pool.query(
              `SELECT task_id,
                      COALESCE(SUM(actual_minutes),0)::int AS minutes
               FROM focus_sessions
               WHERE task_id = ANY($1) GROUP BY task_id`,
              [ids])
          : Promise.resolve({ rows: [] }),
      ]);
      const focusById = new Map(
        focus.rows.map((f) => [f.task_id, f.minutes]));
      for (const t of rows) {
        if (wantSubs) {
          t.subtasks = subs.rows.filter((s) => s.task_id === t.id);
        }
        if (wantFocus) {
          t.focus_minutes = focusById.get(t.id) ?? 0;
        }
      }
    }
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load tasks' });
  }
});

app.post('/api/tasks', requireAuth, async (req, res) => {
  try {
    const {
      title,
      tag = 'General',
      status = 'todo',
      folder = 'Productivity',
      avatar_label = '禅',
      description = '',
      priority = 'none',
      recurring = 'none',
      position = 0,
    } = req.body;
    if (!title || !String(title).trim()) return res.status(400).json({ error: 'title required' });
    const cleanTitle = String(title).trim().slice(0, 500);
    const cleanTag = String(tag).trim().slice(0, 60) || 'General';
    const cleanFolder = String(folder).trim().slice(0, 80) || 'Productivity';
    const cleanDesc = String(description ?? '').trim().slice(0, 5000);
    const cleanPriority = ['none', 'low', 'medium', 'high'].includes(priority) ? priority : 'none';
    const cleanRecurring = ['none', 'daily', 'weekdays', 'weekly', 'monthly'].includes(recurring) ? recurring : 'none';

    // Auto-create folder if it doesn't exist for user
    await pool.query(
      'INSERT INTO folders (name, icon, user_id) VALUES ($1, $2, $3) ON CONFLICT (user_id, name) DO NOTHING',
      [cleanFolder, 'folder', req.userId]
    );

    const clientId = typeof req.body?.client_id === 'string'
      ? req.body.client_id.slice(0, 64)
      : null;
    if (clientId) {
      const { rows: dup } = await pool.query(
        'SELECT * FROM tasks WHERE client_id = $1', [clientId]);
      if (dup.length) {
        if (dup[0].user_id !== req.userId) {
          return res.status(409).json({ error: 'duplicate request' });
        }
        return res.status(200).json(dup[0]);
      }
    }
    const hasDue = req.body && Object.prototype.hasOwnProperty.call(req.body, 'due_at');
    const due = hasDue && req.body.due_at ? req.body.due_at : null;

    const { rows } = await pool.query(
      `INSERT INTO tasks (title, tag, status, folder, avatar_label, description, priority, recurring, position, due_at, user_id, client_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
      [cleanTitle, cleanTag, status, cleanFolder, avatar_label, cleanDesc, cleanPriority, cleanRecurring, position, due, req.userId, clientId],
    );
    await logEvent(rows[0].id, req.userId, 'created', { to: rows[0].status });
    await runRules('task_created', rows[0], req.userId);
    res.status(201).json(rows[0]);
  } catch (e) {
    console.error('[tasks] create failed:', e);
    res.status(500).json({ error: 'could not create task' });
  }
});

app.patch('/api/tasks/:id', requireAuth, async (req, res) => {
  try {
    const { status, title, tag, description, priority, folder, recurring, position } = req.body ?? {};
    const hasDue = req.body && Object.prototype.hasOwnProperty.call(req.body, 'due_at');
    const due = hasDue ? (req.body.due_at || null) : null;
    const clearDue = hasDue && req.body.due_at == null;

    const { rows: old } = await pool.query(
      'SELECT * FROM tasks WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!old.length) return res.status(404).json({ error: 'not found' });
    const before = old[0];

    // If folder changed, ensure new folder exists
    if (folder && folder !== before.folder) {
      await pool.query(
        'INSERT INTO folders (name, icon, user_id) VALUES ($1, $2, $3) ON CONFLICT (user_id, name) DO NOTHING',
        [folder, 'folder', req.userId]
      );
    }

    const { rows } = await pool.query(
      `UPDATE tasks SET
         status = COALESCE($2, status),
         title = COALESCE($3, title),
         tag = COALESCE($4, tag),
         description = COALESCE($5, description),
         priority = COALESCE($6, priority),
         folder = COALESCE($7, folder),
         recurring = COALESCE($8, recurring),
         position = COALESCE($9, position),
         due_at = CASE WHEN $10 THEN NULL WHEN $11::timestamptz IS NULL THEN due_at ELSE $11::timestamptz END
       WHERE id = $1 AND user_id = $12 RETURNING *`,
      [
        req.params.id,
        status ?? null,
        title ? String(title).trim().slice(0, 500) : null,
        tag ? String(tag).trim().slice(0, 60) : null,
        description !== undefined ? String(description).slice(0, 5000) : null,
        priority ?? null,
        folder ? String(folder).trim().slice(0, 80) : null,
        recurring ?? null,
        typeof position === 'number' ? position : null,
        clearDue,
        due,
        req.userId,
      ],
    );
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    const after = rows[0];
    if (after.status !== before.status) {
      await logEvent(after.id, req.userId, 'status', { from: before.status, to: after.status });
      await runRules('task_moved', after, req.userId);
      if (after.status === 'done') {
        await runRules('task_done', after, req.userId);
        if (after.recurring && after.recurring !== 'none') {
          let nextDue = null;
          const base = after.due_at ? new Date(after.due_at) : new Date();
          if (after.recurring === 'daily') {
            nextDue = new Date(base.getTime() + 24 * 60 * 60 * 1000);
          } else if (after.recurring === 'weekdays') {
            const day = base.getDay();
            const addDays = (day === 5) ? 3 : (day === 6) ? 2 : 1;
            nextDue = new Date(base.getTime() + addDays * 24 * 60 * 60 * 1000);
          } else if (after.recurring === 'weekly') {
            nextDue = new Date(base.getTime() + 7 * 24 * 60 * 60 * 1000);
          } else if (after.recurring === 'monthly') {
            nextDue = new Date(base);
            nextDue.setMonth(nextDue.getMonth() + 1);
          }
          if (nextDue) {
            await pool.query(
              `INSERT INTO tasks (title, tag, status, folder, avatar_label, description, priority, recurring, due_at, user_id)
               VALUES ($1, $2, 'todo', $3, $4, $5, $6, $7, $8, $9)`,
              [after.title, after.tag, after.folder, after.avatar_label, after.description, after.priority, after.recurring, nextDue, req.userId]
            );
          }
        }
      }
    }
    if (after.title !== before.title) {
      await logEvent(after.id, req.userId, 'renamed', { body: after.title });
    }
    if (after.folder !== before.folder) {
      await logEvent(after.id, req.userId, 'folder', { body: `${before.folder} → ${after.folder}` });
    }
    res.json(rows[0]);
  } catch (e) {
    console.error('[tasks] patch failed:', e);
    res.status(500).json({ error: 'could not update task' });
  }
});

// Phase A — history ("flow") + subtasks.

// Per-task timeline, oldest first. 404 unless the task is yours.
app.get('/api/tasks/:id/events', requireAuth, async (req, res) => {
  try {
    const { rows: own } = await pool.query(
      'SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!own.length) return res.status(404).json({ error: 'not found' });
    const { rows } = await pool.query(
      `SELECT * FROM task_events WHERE task_id = $1 ORDER BY created_at`, [req.params.id]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load history' });
  }
});

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

// Standup-style progress note on a task ("how we proceeded").
app.post('/api/tasks/:id/notes', requireAuth, async (req, res) => {
  try {
    const body = String(req.body?.body ?? '').trim().slice(0, 1000);
    if (!body) return res.status(400).json({ error: 'write the note first' });
    const { rows: task } = await pool.query(
      'SELECT * FROM tasks WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!task.length) return res.status(404).json({ error: 'task not found' });
    const { rows } = await pool.query(
      `INSERT INTO task_events (task_id, user_id, kind, body)
       VALUES ($1, $2, 'note', $3) RETURNING *`,
      [req.params.id, req.userId, body],
    );
    await runRules('note_added', task[0], req.userId);
    res.status(201).json(rows[0]);
  } catch {
    res.status(500).json({ error: 'could not save note' });
  }
});

// Subtasks (single-level checklist under a parent task).
app.get('/api/tasks/:id/subtasks', requireAuth, async (req, res) => {
  try {
    const { rows: own } = await pool.query(
      'SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!own.length) return res.status(404).json({ error: 'not found' });
    const { rows } = await pool.query(
      `SELECT * FROM subtasks WHERE task_id = $1 ORDER BY position, created_at`, [req.params.id]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load subtasks' });
  }
});

app.post('/api/tasks/:id/subtasks', requireAuth, async (req, res) => {
  try {
    const title = String(req.body?.title ?? '').trim().slice(0, 200);
    if (!title) return res.status(400).json({ error: 'title required' });
    const { rows: task } = await pool.query(
      'SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!task.length) return res.status(404).json({ error: 'task not found' });
    const { rows: pos } = await pool.query(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM subtasks WHERE task_id = $1', [req.params.id]);
    const { rows } = await pool.query(
      `INSERT INTO subtasks (task_id, title, position)
       VALUES ($1, $2, $3) RETURNING *`,
      [req.params.id, title, pos[0].next],
    );
    res.status(201).json(rows[0]);
  } catch {
    res.status(500).json({ error: 'could not add subtask' });
  }
});

app.patch('/api/subtasks/:id', requireAuth, async (req, res) => {
  try {
    const { title, done, position } = req.body ?? {};
    // Completion is final: read first so a done subtask can never be
    // unchecked (015). The UI confirms before checking; this guards
    // every client, including stale ones and raw API calls.
    const { rows: existing } = await pool.query(
      `SELECT s.* FROM subtasks s JOIN tasks t ON s.task_id = t.id
       WHERE s.id = $1 AND t.user_id = $2`,
      [req.params.id, req.userId],
    );
    if (!existing.length) return res.status(404).json({ error: 'not found' });
    if (done === false && existing[0].completed_at) {
      return res.status(409).json({ error: 'Subtask already done — completion is final.' });
    }
    const { rows } = await pool.query(
      `UPDATE subtasks s SET
         title = COALESCE($2, s.title),
         done = COALESCE($3, s.done),
         position = COALESCE($4, s.position),
         completed_at = CASE
           WHEN $3 = TRUE THEN COALESCE(s.completed_at, now())
           ELSE s.completed_at
         END
       FROM tasks t
       WHERE s.id = $1 AND s.task_id = t.id AND t.user_id = $5
       RETURNING s.*`,
      [req.params.id, title ?? null, done ?? null, position ?? null, req.userId],
    );
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    // Subtask ticks are history too (History screen, timelines, activity).
    if (typeof done === 'boolean') {
      await logEvent(rows[0].task_id, req.userId, 'subtask', {
        to: done ? 'done' : 'todo',
        body: rows[0].title,
      });
    }
    // A completed subtask that finishes the whole checklist fires the flow.
    if (rows[0].done) {
      const { rows: open } = await pool.query(
        'SELECT id FROM subtasks WHERE task_id = $1 AND NOT done', [rows[0].task_id]);
      if (!open.length) {
        const { rows: parent } = await pool.query(
          'SELECT * FROM tasks WHERE id = $1', [rows[0].task_id]);
        if (parent.length) {
          await runRules('subtasks_complete', parent[0], req.userId);
        }
      }
    }
    res.json(rows[0]);
  } catch (e) {
    console.error('[subtasks] patch failed:', e);
    res.status(500).json({ error: 'could not update subtask' });
  }
});

app.delete('/api/subtasks/:id', requireAuth, async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      `DELETE FROM subtasks s USING tasks t
       WHERE s.id = $1 AND s.task_id = t.id AND t.user_id = $2`,
      [req.params.id, req.userId]);
    if (!rowCount) return res.status(404).json({ error: 'not found' });
    res.status(204).end();
  } catch {
    res.status(500).json({ error: 'could not delete subtask' });
  }
});

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

app.get('/api/wallet', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT balance FROM user_tokens WHERE user_id = $1', [req.userId]);
    res.json({ balance: rows.length ? rows[0].balance : 450 });
  } catch {
    res.status(500).json({ error: 'could not load wallet' });
  }
});

app.get('/api/inbox', requireAuth, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit ?? '50', 10) || 50, 200);
    const { rows } = await pool.query(
      'SELECT * FROM inbox_messages WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2',
      [req.userId, limit]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not load inbox' });
  }
});

app.patch('/api/inbox/:id', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `UPDATE inbox_messages SET unread = COALESCE($3, unread)
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      [req.params.id, req.userId, req.body?.unread ?? null],
    );
    if (!rows.length) return res.status(404).json({ error: 'not found' });
    res.json(rows[0]);
  } catch {
    res.status(500).json({ error: 'could not update message' });
  }
});

// --- Phase B: focus timer ---

// Start a timer on a task.
app.post('/api/focus', requireAuth, async (req, res) => {
  try {
    const minutes = Math.max(1, Math.min(180, parseInt(req.body?.minutes ?? 25, 10) || 25));
    const mode = req.body?.mode === 'break' ? 'break' : 'focus';
    const { rows: task } = await pool.query(
      'SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [req.body?.task_id, req.userId]);
    if (!task.length) return res.status(404).json({ error: 'task not found' });
    const { rows } = await pool.query(
      `INSERT INTO focus_sessions (task_id, user_id, mode, planned_minutes)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.body.task_id, req.userId, mode, minutes]);
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
        await logEvent(parent[0].id, req.userId, 'note',
          { body: subtask
              ? `Focused ${s.planned_minutes} min on "${subtask}"`
              : `Focused ${s.planned_minutes} min` });
        await runRules('focus_done', parent[0], req.userId);
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

// --- Theme store: catalog mirrors the Flutter palettes 1:1.
// Prices here; pixels there. Edo and Midnight are free baselines
// owned by everyone (Midnight is the default dark look).
const THEMES = {
  edo: { id: 'edo', name: 'Edo Period', label: 'CLASSIC', price: 0 },
  midnight: { id: 'midnight', name: 'Midnight Tokyo', label: 'MODERN', price: 0 },
  ocean: { id: 'ocean', name: 'Kamogawa Blue', label: 'OCEAN', price: 650 },
  kyoto: { id: 'kyoto', name: 'Kyoto Garden', label: 'NATURE', price: 500 },
};

app.get('/api/store', requireAuth, async (req, res) => {
  try {
    const { rows: owned } = await pool.query(
      'SELECT theme_id FROM owned_themes WHERE user_id = $1', [req.userId]);
    const have = new Set(owned.map((r) => r.theme_id));
    const { rows: me } = await pool.query(
      'SELECT active_theme FROM users WHERE id = $1', [req.userId]);
    const { rows: wallet } = await pool.query(
      'SELECT balance FROM user_tokens WHERE user_id = $1', [req.userId]);
    res.json({
      balance: wallet.length ? wallet[0].balance : 450,
      active: me.length ? me[0].active_theme : 'midnight',
      themes: Object.values(THEMES).map((t) => ({
        ...t,
        owned: have.has(t.id),
      })),
    });
  } catch {
    res.status(500).json({ error: 'could not load store' });
  }
});

// Buy: atomic deduct + grant. Idempotent — owning it returns ok.
app.post('/api/store/buy', requireAuth, async (req, res) => {
  try {
    const id = String(req.body?.theme_id ?? '');
    const theme = THEMES[id];
    if (!theme) return res.status(400).json({ error: 'unknown theme' });
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const { rows: owned } = await client.query(
        'SELECT 1 FROM owned_themes WHERE user_id = $1 AND theme_id = $2',
        [req.userId, id]);
      if (owned.length) {
        await client.query('ROLLBACK');
        return res.json({ ok: true, owned: true });
      }
      const { rows: wallet } = await client.query(
        'SELECT balance FROM user_tokens WHERE user_id = $1 FOR UPDATE',
        [req.userId]);
      const balance = wallet.length ? wallet[0].balance : 450;
      if (balance < theme.price) {
        await client.query('ROLLBACK');
        return res.status(402).json({ error: 'not enough tokens — complete tasks and flows to earn more' });
      }
      if (!wallet.length) {
        await client.query(
          'INSERT INTO user_tokens (user_id, balance) VALUES ($1, $2)',
          [req.userId, 450 - theme.price]);
      } else {
        await client.query(
          'UPDATE user_tokens SET balance = balance - $2, updated_at = now() WHERE user_id = $1',
          [req.userId, theme.price]);
      }
      await client.query(
        'INSERT INTO owned_themes (user_id, theme_id) VALUES ($1, $2)',
        [req.userId, id]);
      await client.query('COMMIT');
      res.status(201).json({ ok: true });
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } catch {
    res.status(500).json({ error: 'could not buy theme' });
  }
});

// Equip: must own it.
app.post('/api/store/equip', requireAuth, async (req, res) => {
  try {
    const id = String(req.body?.theme_id ?? '');
    if (!THEMES[id]) return res.status(400).json({ error: 'unknown theme' });
    const { rows: owned } = await pool.query(
      'SELECT 1 FROM owned_themes WHERE user_id = $1 AND theme_id = $2',
      [req.userId, id]);
    if (!owned.length) return res.status(403).json({ error: 'buy it first' });
    await pool.query('UPDATE users SET active_theme = $2 WHERE id = $1',
      [req.userId, id]);
    res.json({ ok: true, active: id });
  } catch {
    res.status(500).json({ error: 'could not equip theme' });
  }
});

// --- Batch: delete, search, export, password reset ---

app.delete('/api/tasks/:id', requireAuth, async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM tasks WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
    if (!rowCount) return res.status(404).json({ error: 'not found' });
    res.status(204).end();
  } catch {
    res.status(500).json({ error: 'could not delete task' });
  }
});

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

// Batch reorder tasks
app.patch('/api/tasks-reorder', requireAuth, async (req, res) => {
  try {
    const { items } = req.body ?? {};
    if (Array.isArray(items)) {
      for (const item of items) {
        if (item.id && typeof item.position === 'number') {
          await pool.query(
            'UPDATE tasks SET position = $1 WHERE id = $2 AND user_id = $3',
            [item.position, item.id, req.userId]
          );
        }
      }
    }
    res.json({ ok: true });
  } catch {
    res.status(500).json({ error: 'could not reorder tasks' });
  }
});

app.get('/api/tasks/search', requireAuth, async (req, res) => {
  try {
    const q = String(req.query.q ?? '').trim();
    if (q.length < 2) {
      return res.status(400).json({ error: 'type at least 2 letters' });
    }
    const { rows } = await pool.query(
      `SELECT * FROM tasks
       WHERE user_id = $1 AND (title ILIKE $2 OR tag ILIKE $2 OR description ILIKE $2)
       ORDER BY created_at DESC LIMIT 30`,
      [req.userId, `%${q}%`]);
    res.json(rows);
  } catch {
    res.status(500).json({ error: 'could not search' });
  }
});

// Full account dump (the privacy policy promises export on request).
app.get('/api/export', requireAuth, async (req, res) => {
  try {
    const u = req.userId;
    const [me, tasks, folders, rules, inbox, wallet, focus] = await Promise.all([
      pool.query('SELECT * FROM users WHERE id = $1', [u]),
      pool.query('SELECT * FROM tasks WHERE user_id = $1 ORDER BY created_at', [u]),
      pool.query('SELECT * FROM folders WHERE user_id = $1 ORDER BY created_at', [u]),
      pool.query('SELECT * FROM rules WHERE user_id = $1 ORDER BY created_at', [u]),
      pool.query('SELECT * FROM inbox_messages WHERE user_id = $1 ORDER BY created_at', [u]),
      pool.query('SELECT balance FROM user_tokens WHERE user_id = $1', [u]),
      pool.query('SELECT * FROM focus_sessions WHERE user_id = $1 ORDER BY started_at', [u]),
    ]);
    const ids = tasks.rows.map((t) => t.id);
    const [subs, events] = ids.length
      ? await Promise.all([
          pool.query('SELECT * FROM subtasks WHERE task_id = ANY($1) ORDER BY position', [ids]),
          pool.query('SELECT * FROM task_events WHERE task_id = ANY($1) ORDER BY created_at', [ids]),
        ])
      : [{ rows: [] }, { rows: [] }];
    res.json({
      exported_at: new Date().toISOString(),
      user: me.rows.length ? publicUser(me.rows[0]) : null,
      wallet: wallet.rows.length ? wallet.rows[0].balance : 450,
      folders: folders.rows,
      tasks: tasks.rows.map((t) => ({
        ...t,
        subtasks: subs.rows.filter((s) => s.task_id === t.id),
        events: events.rows.filter((e) => e.task_id === t.id),
      })),
      rules: rules.rows,
      inbox: inbox.rows,
      focus_sessions: focus.rows,
    });
  } catch {
    res.status(500).json({ error: 'could not export data' });
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

const port = process.env.PORT || 8080;
app.listen(port, () => console.log(`daily-bloom-api on :${port}`));