// One-off test seed: 50 realistic tasks + all themes for one account.
// Usage: node scripts/seed_test_account.js raghav@gmail.com
// Idempotent: wipes this account's previous TESTSEED rows first.
import pg from 'pg';

const pool = new pg.Pool({
  connectionString:
    process.env.DATABASE_URL ??
    'postgres://bloom:bloom_dev_password@localhost:5433/daily_bloom',
});

const email = (process.argv[2] ?? 'raghav@gmail.com').toLowerCase().trim();
const { rows: u } = await pool.query('SELECT id, email FROM users WHERE email = $1', [email]);
if (!u.length) throw new Error(`no such user: ${email} (log in once first so the row exists)`);
const uid = u[0].id;

// Clear previous seed rows for idempotency.
await pool.query(`DELETE FROM subtasks WHERE task_id IN
  (SELECT id FROM tasks WHERE user_id = $1 AND title LIKE 'TESTSEED-%')`, [uid]);
await pool.query(`DELETE FROM tasks WHERE user_id = $1 AND title LIKE 'TESTSEED-%'`, [uid]);

for (const name of ['Work', 'Personal', 'Health', 'Learning']) {
  await pool.query(
    `INSERT INTO folders (user_id, name, icon)
     SELECT $1, $2, 'folder'
     WHERE NOT EXISTS (SELECT 1 FROM folders WHERE user_id = $1 AND name = $2)`,
    [uid, name],
  );
}

const day = 24 * 3600 * 1000;
const now = Date.now();
const iso = (ms) => new Date(ms).toISOString();

// [title, tag, folder, status, priority, dueMs|null]
const seed = [
  // Overdue — planner should surface these first.
  ['TESTSEED-01 File expense report', 'Work', 'Work', 'todo', 'high', now - day],
  ['TESTSEED-02 Pay electricity bill', 'Home', 'Personal', 'todo', 'high', now - 2 * day],
  ['TESTSEED-03 Dentist follow-up call', 'Health', 'Health', 'todo', 'none', now - day],
  ['TESTSEED-04 Review PR from Anita', 'Work', 'Work', 'in_progress', 'high', now - 3 * 3600 * 1000],
  ['TESTSEED-05 Renew domain', 'Work', 'Work', 'todo', 'none', now - 4 * day],
  // Due today / tomorrow.
  ['TESTSEED-06 Prepare sprint demo slides', 'Work', 'Work', 'todo', 'high', now + 4 * 3600 * 1000],
  ['TESTSEED-07 Grocery run for the week', 'Home', 'Personal', 'todo', 'none', now + 6 * 3600 * 1000],
  ['TESTSEED-08 Morning run 5k', 'Health', 'Health', 'todo', 'none', now + 8 * 3600 * 1000],
  ['TESTSEED-09 Read 30 pages of Atomic Habits', 'Learning', 'Learning', 'in_progress', 'none', now + 10 * 3600 * 1000],
  ['TESTSEED-10 Call mom', 'Home', 'Personal', 'todo', 'none', now + day],
  ['TESTSEED-11 Fix login flicker bug', 'Work', 'Work', 'in_progress', 'high', now + day],
  ['TESTSEED-12 Water the plants', 'Home', 'Personal', 'todo', 'none', now + day],
  ['TESTSEED-13 Meditate 10 minutes', 'Health', 'Health', 'todo', 'none', now + 2 * day],
  // High priority, no due date.
  ['TESTSEED-14 Draft launch announcement', 'Work', 'Work', 'todo', 'high', null],
  ['TESTSEED-15 Backup laptop', 'Home', 'Personal', 'todo', 'high', null],
  ['TESTSEED-16 Schedule annual checkup', 'Health', 'Health', 'todo', 'none', null],
  // In progress.
  ['TESTSEED-17 Refactor auth middleware', 'Work', 'Work', 'in_progress', 'none', null],
  ['TESTSEED-18 Course: Flutter animations ch3', 'Learning', 'Learning', 'in_progress', 'none', null],
  // Regular backlog (todo).
  ['TESTSEED-19 Plan weekend trip', 'Idea', 'Personal', 'todo', 'none', null],
  ['TESTSEED-20 Tidy desk drawer', 'Home', 'Personal', 'todo', 'none', null],
  ['TESTSEED-21 Write journal entry', 'Idea', 'Personal', 'todo', 'none', null],
  ['TESTSEED-22 Stretch + mobility 15 min', 'Health', 'Health', 'todo', 'none', null],
  ['TESTSEED-23 Update resume', 'Work', 'Work', 'todo', 'none', now + 3 * day],
  ['TESTSEED-24 Learn three new chords', 'Learning', 'Learning', 'todo', 'none', null],
  ['TESTSEED-25 Organize photos backup', 'Home', 'Personal', 'todo', 'none', null],
  ['TESTSEED-26 Try new pasta recipe', 'Idea', 'Personal', 'todo', 'none', now + 4 * day],
  ['TESTSEED-27 Review monthly budget', 'Home', 'Personal', 'todo', 'none', now + 5 * day],
  ['TESTSEED-28 Practice presentation once', 'Work', 'Work', 'todo', 'none', now + 2 * day],
  ['TESTSEED-29 Oil the bicycle chain', 'Home', 'Personal', 'todo', 'none', null],
  ['TESTSEED-30 Donate old clothes', 'Home', 'Personal', 'todo', 'none', null],
  ['TESTSEED-31 Sketch app icon ideas', 'Idea', 'Personal', 'todo', 'none', null],
  ['TESTSEED-32 Deep clean fridge', 'Home', 'Personal', 'todo', 'none', now + 6 * day],
  ['TESTSEED-33 Finish podcast episode notes', 'Learning', 'Learning', 'todo', 'none', null],
  ['TESTSEED-34 Order birthday gift', 'Home', 'Personal', 'todo', 'none', now + 3 * day],
  ['TESTSEED-35 Evening walk without phone', 'Health', 'Health', 'todo', 'none', null],
  ['TESTSEED-36 Write thank-you note', 'Home', 'Personal', 'todo', 'none', null],
  ['TESTSEED-37 Research standing desks', 'Idea', 'Personal', 'todo', 'none', null],
  ['TESTSEED-38 Update emergency contacts', 'Home', 'Personal', 'todo', 'none', null],
  ['TESTSEED-39 Floss + skincare routine', 'Health', 'Health', 'todo', 'none', null],
  ['TESTSEED-40 Brainstorm birthday surprise', 'Idea', 'Personal', 'todo', 'none', null],
  ['TESTSEED-41 Clean inbox to zero', 'Work', 'Work', 'todo', 'none', null],
  ['TESTSEED-42 Learn vim motions', 'Learning', 'Learning', 'todo', 'none', null],
  ['TESTSEED-43 Fix squeaky door', 'Home', 'Personal', 'todo', 'none', null],
  ['TESTSEED-44 Plan Diwali gifts list', 'Home', 'Personal', 'todo', 'none', now + 7 * day],
  ['TESTSEED-45 Try 25-min focus sprint', 'Work', 'Work', 'todo', 'none', null],
  // A few done rows so heat/progress look alive.
  ['TESTSEED-46 Morning pages', 'Idea', 'Personal', 'done', 'none', now - day],
  ['TESTSEED-47 Gym session', 'Health', 'Health', 'done', 'none', now - day],
  ['TESTSEED-48 Ship v0.9 notes', 'Work', 'Work', 'done', 'none', now - 2 * day],
  ['TESTSEED-49 Clean balcony', 'Home', 'Personal', 'done', 'none', now - 3 * day],
  ['TESTSEED-50 Read 20 pages', 'Learning', 'Learning', 'done', 'none', now - 2 * day],
];

const ids = [];
for (const [title, tag, folder, status, priority, dueMs] of seed) {
  const done = status === 'done';
  const res = await pool.query(
    `INSERT INTO tasks (title, tag, status, folder, priority, due_at, completed_at, user_id)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
    [title, tag, status, folder, priority, dueMs ? iso(dueMs) : null, done ? new Date().toISOString() : null, uid],
  );
  ids.push(res.rows[0].id);
}

// Subtasks on a few open tasks so breakdown/progress render.
const subSeeds = [
  [0, ['Gather receipts', 'Fill the form', 'Submit + save ack']],
  [5, ['Outline 5 slides', 'Add numbers', 'Rehearse once']],
  [10, ['Reproduce on staging', 'Fix + test', 'Open PR']],
];
let subCount = 0;
for (const [ti, titles] of subSeeds) {
  for (let s = 0; s < titles.length; s++) {
    await pool.query('INSERT INTO subtasks (task_id, title, done, position) VALUES ($1, $2, $3, $4)', [
      ids[ti],
      titles[s],
      false,
      s,
    ]);
    subCount++;
  }
}

// Unlock every theme (edo/midnight free; ocean + kyoto granted).
for (const theme of ['edo', 'midnight', 'ocean', 'kyoto']) {
  await pool.query(
    `INSERT INTO owned_themes (user_id, theme_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [uid, theme],
  );
}
const owned = await pool.query('SELECT theme_id FROM owned_themes WHERE user_id = $1 ORDER BY theme_id', [uid]);

console.log(
  JSON.stringify({
    email,
    tasksInserted: ids.length,
    subtasksInserted: subCount,
    themes: owned.rows.map((r) => r.theme_id),
  }),
);
await pool.end();
