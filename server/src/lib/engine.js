// Rules engine + theme catalog. Moved verbatim from src/index.js
// (route split) except pool, which is now an explicit first argument.
// No logic changes.

// Append-only history writer. Never throws: a logging failure must not
// fail the user's actual action, so errors are swallowed after a log line.
export async function logEvent(pool, taskId, userId, kind, { from = null, to = null, body = '' } = {}) {
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

export function condMatches(c, task) {
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

export function ruleMatches(rule, task) {
  return condMatches(rule.condition, task);
}

export async function runRuleActions(pool, rule, task, userId) {
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
        await logEvent(pool, task.id, userId, 'status',
          { from: task.status, to, body: `via rule ${rule.name}` });
        task.status = to;
      }
      done.push({ type: 'move_task', to });
    } else if (a.type === 'complete_parent') {
      if (task.status !== 'done') {
        await pool.query("UPDATE tasks SET status = 'done' WHERE id = $1", [task.id]);
        await logEvent(pool, task.id, userId, 'status',
          { from: task.status, to: 'done', body: `via rule ${rule.name}` });
        task.status = 'done';
      }
      done.push({ type: 'complete_parent' });
    }
  }
  return done;
}

export async function runRules(pool, trigger, task, userId) {
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
        const actions = await runRuleActions(pool, rule, { ...task }, userId);
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

export function validCondition(c) {
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

export function validRuleBody(b) {
  if (!b || typeof b !== 'object') return 'invalid rule';
  if (!RULE_TRIGGERS.includes(b.trigger)) return 'unknown trigger';
  if (!Array.isArray(b.actions) || !b.actions.length) return 'add at least one action';
  for (const a of b.actions) {
    if (!a || !RULE_ACTIONS.includes(a.type)) return 'unknown action';
  }
  return validCondition(b.condition ?? {});
}

// --- Theme store: catalog mirrors the Flutter palettes 1:1.
// Prices here; pixels there. Edo and Midnight are free baselines
// owned by everyone (Midnight is the default dark look).
export const THEMES = {
  edo: { id: 'edo', name: 'Edo Period', label: 'CLASSIC', price: 0 },
  midnight: { id: 'midnight', name: 'Midnight Tokyo', label: 'MODERN', price: 0 },
  ocean: { id: 'ocean', name: 'Kamogawa Blue', label: 'OCEAN', price: 650 },
  kyoto: { id: 'kyoto', name: 'Kyoto Garden', label: 'NATURE', price: 500 },
};