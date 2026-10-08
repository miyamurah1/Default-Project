// Creates (or resets) a ready-to-use demo account with a realistic board:
// ~50 tasks spread over todo / in_progress / done, every task carrying
// 2-3 subtasks, plus per-task history and 12 weeks of heatmap activity so
// streaks, insights and the kanban all have something to show.
//
// Login is Firebase-only, so this creates the Firebase Auth user *and*
// the DB row (same seeds firebase-sync applies on first sign-in).
//
// Usage: node scripts/demo_account.js [email] [password] [taskCount]
//   defaults: demo@dailybloom.app  Bloom12345!  50
//
// Idempotent: re-running wipes only this account's demo content and
// rebuilds it. Other accounts are never touched.
import 'dotenv/config';
import { readFileSync } from 'node:fs';
import pg from 'pg';
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const EMAIL = (process.argv[2] ?? 'demo@dailybloom.app').toLowerCase().trim();
const PASSWORD = process.argv[3] ?? 'Bloom12345!';
const TASK_COUNT = Math.max(1, parseInt(process.argv[4] ?? '50', 10) || 50);
const DISPLAY_NAME = 'Bloom Demo';
const API_URL = process.env.API_URL ?? 'http://localhost:8080';

const pool = new pg.Pool({
  connectionString:
    process.env.DATABASE_URL ??
    'postgres://bloom:bloom_dev_password@localhost:5433/daily_bloom',
});

// --- Firebase Admin (service account from env or the checked-in file) ---

const raw = process.env.FIREBASE_SERVICE_ACCOUNT
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT)
  : JSON.parse(
      readFileSync(new URL('../firebase-service-account.json', import.meta.url), 'utf8'),
    );
initializeApp({ credential: cert(raw) });
const auth = getAuth();

// --- Content -------------------------------------------------------------
// status, folder, tag, priority, title, description, dueInDays (null = none),
// recurring, steps (2-3 per task; the first step is usually done already).
const NOW = Date.now();
const DAY = 24 * 60 * 60 * 1000;
const daysAgo = (n) => new Date(NOW - n * DAY);

const BLUEPRINT = [
  // --- done (older work, keeps the heatmap and insights alive) ---
  ['done', 'Productivity', 'Design', 'medium', 'Redesign the home task list card', 'Sketch spacing, shadow and the tap target on the sketch-style card.', 0, 'none',
    ['Draft two card variants', 'Pick one with the design review', 'Ship to the web build']],
  ['done', 'Personal Projects', 'Build', 'high', 'Wire the kanban drag-and-drop to the API', 'Reorder on drop, persist position, keep the board from flickering.', 0, 'none',
    ['Optimistic reorder locally', 'PATCH position on drop', 'Verify two browsers stay in sync']],
  ['done', 'Self Care', 'Ritual', 'low', 'Set up the morning meditation routine', 'Ten minutes of breathing before the first inbox check.', 0, 'daily',
    ['Pick a 10-minute track', 'Block 07:00 on weekdays', 'Track it for one week']],
  ['done', 'Productivity', 'Build', 'high', 'Add the OAuth refresh-token rotation', 'Refresh tokens expire after 30 days — swap them before the API rejects them.', 0, 'none',
    ['Detect expiry on 401', 'Exchange and retry once', 'Cover it with a test']],
  ['done', 'Self Care', 'Care', 'low', 'Evening shutdown checklist to close the day', 'Write tomorrow’s top three, close every tab, then stop.', 0, 'weekdays',
    ['List tomorrow’s three', 'Archive open tasks', 'Screens off at 22:00']],
  ['done', 'Personal Projects', 'Write', 'medium', 'Outline the daily-bloom launch post', 'What the app is, who it is for, and a screenshot or two.', 0, 'none',
    ['Draft the hook', 'Add three screenshots', 'Proofread the tags']],
  ['done', 'Productivity', 'Product', 'medium', 'Cut the API response time for the task list', 'One round trip with embedded subtasks instead of N+1 per card.', 0, 'none',
    ['Profile the list endpoint', 'Embed subtasks in the same query', 'Re-measure p95']],
  ['done', 'Self Care', 'Health', 'medium', 'Replace the afternoon coffee with a walk', 'Fifteen minutes outside beats the third cup.', 0, 'none',
    ['Set a 15:30 reminder', 'Walk without headphones once', 'Drop the second coffee']],
  ['done', 'Personal Projects', 'Design', 'low', 'Sakura theme palette pass', 'Soften the pinks, lift the contrast on the muted text.', 0, 'none',
    ['Sample the palette', 'Check contrast ratios', 'Apply to the theme file']],
  ['done', 'Productivity', 'Care', 'low', 'Archive the abandoned side projects', 'Anything untouched for 90 days moves to the archive folder.', 0, 'none',
    ['Filter by last updated', 'Move stale cards', 'Write a one-line reason']],
  ['done', 'Self Care', 'Ritual', 'medium', 'Weekly review with the heatmap', 'Look at the last 12 weeks and pick one thing to drop.', 0, 'weekly',
    ['Read the heatmap', 'Pick one habit to drop', 'Set next week’s focus']],
  ['done', 'Personal Projects', 'Build', 'medium', 'Publish the first GitHub release', 'Tag, changelog, and a smoke-tested web build.', 0, 'none',
    ['Tag v0.1.0', 'Write the changelog', 'Verify the web build boots']],

  // --- in_progress ---
  ['in_progress', 'Productivity', 'Design', 'high', 'Rebuild the focus timer card', 'Progress ring, pause/resume, and the session summary underneath.', 1, 'none',
    ['Draw the ring states', 'Handle pause + resume', 'Show minutes at the end']],
  ['in_progress', 'Personal Projects', 'Build', 'high', 'Offline mode for the task list', 'Cache the last board so the app opens on a dead train connection.', 4, 'none',
    ['Cache the task payload', 'Replay queued writes', 'Show a stale-data banner']],
  ['in_progress', 'Productivity', 'Product', 'medium', 'Trim the onboarding to three steps', 'Sign in, pick folders, start the first task. Nothing else.', 2, 'none',
    ['Cut to three steps', 'Auto-create starter folders', 'Measure drop-off']],
  ['in_progress', 'Self Care', 'Health', 'medium', 'Two workouts a week, non-negotiable', 'Strength on Tuesday, long walk on Saturday.', 3, 'weekly',
    ['Book Tuesday 18:00', 'Pick the Saturday route', 'Track both on the calendar']],
  ['in_progress', 'Personal Projects', 'Write', 'low', 'Rewrite the empty states in a calm tone', 'No guilt, no exclamation marks — say what happens next.', 6, 'none',
    ['List every empty state', 'Rewrite the copy', 'Ask someone to read them aloud']],
  ['in_progress', 'Productivity', 'Build', 'medium', 'Paginate the activity feed', 'Fifty events per page, infinite scroll on the History tab.', 5, 'none',
    ['Add ?limit and ?before', 'Wire the scroll listener', 'Keep scroll position on return']],
  ['in_progress', 'Self Care', 'Ritual', 'low', 'Screen-free Sunday block', 'No phone from 18:00 to dinner.', 7, 'weekly',
    ['Put the phone in the drawer', 'Plan a paper activity', 'Log how it felt']],
  ['in_progress', 'Personal Projects', 'Design', 'medium', 'Concept map for the four systems', 'Tasks, habits, goals and focus feeding each other.', 3, 'none',
    ['Draw the four nodes', 'Connect the flows', 'Animate it on tap']],
  ['in_progress', 'Productivity', 'Care', 'low', 'Delete the analytics I never open', 'Fewer dashboards, more actual work.', 9, 'none',
    ['Audit the screen list', 'Remove two dashboards', 'Move one metric to the home card']],
  ['in_progress', 'Self Care', 'Care', 'medium', 'Fix the sleep schedule', 'Lights out by 23:15, phone out of the bedroom.', 2, 'daily',
    ['Shift lights-out 30 min earlier', 'Charge the phone outside', 'Note wake time for a week']],
  ['in_progress', 'Personal Projects', 'Build', 'medium', 'Move theme prices into the API', 'The catalog lives server-side; the app only renders it.', 8, 'none',
    ['Add the store endpoint', 'Render prices from the payload', 'Delete the hard-coded map']],
  ['in_progress', 'Productivity', 'Product', 'low', 'Weekly planning session', 'Sunday evening: review the week, set three outcomes.', 1, 'weekly',
    ['Review the heatmap', 'Set three outcomes', 'Park everything else']],

  // --- todo (the backlog) ---
  ['todo', 'Productivity', 'Design', 'medium', 'Task detail screen: focus on the description', 'Two-column layout that collapses cleanly on a phone.', 12, 'none',
    ['Sketch two columns', 'Collapse below 600px', 'Add a keyboard shortcut']],
  ['todo', 'Productivity', 'Product', 'medium', 'Decide the default folder for new tasks', 'Today every new card lands in Productivity — is that right?', 14, 'none',
    ['Check where cards actually land', 'Ask three people', 'Ship the default']],
  ['todo', 'Personal Projects', 'Build', 'high', 'Export the board as Markdown', 'A zip of tasks and subtasks for the repo README.', 10, 'none',
    ['Write the exporter', 'Zip the subtasks too', 'Add it to settings']],
  ['todo', 'Self Care', 'Health', 'medium', 'Book the dentist', 'Been on the list for three weeks.', 5, 'none',
    ['Find an evening slot', 'Book it', 'Put it in the calendar']],
  ['todo', 'Self Care', 'Ritual', 'low', 'Start a reading hour', 'Forty pages before bed, paper only.', 20, 'none',
    ['Leave the book on the pillow', 'Set a 21:30 alarm', 'Note the page count']],
  ['todo', 'Personal Projects', 'Design', 'low', 'Icon set pass for the settings screen', 'Six icons that share one stroke weight.', 18, 'none',
    ['Redraw at 24px', 'Check the stroke weight', 'Replace the old set']],
  ['todo', 'Productivity', 'Build', 'medium', 'Rate-limit the search endpoint', 'Search is unscoped and easy to hammer.', 15, 'none',
    ['Add a limiter', 'Return 429 with a retry hint', 'Watch the logs for a day']],
  ['todo', 'Personal Projects', 'Write', 'low', 'Write the privacy policy for the store', 'What we collect, what we never send anywhere.', 25, 'none',
    ['List the data points', 'Plain-language summary', 'Get it reviewed']],
  ['todo', 'Self Care', 'Care', 'medium', 'Meal prep for the week', 'Two hours on Sunday saves six weekday decisions.', 4, 'weekly',
    ['List five meals', 'Shop once', 'Cook and label']],
  ['todo', 'Productivity', 'Product', 'low', 'Ask three people to try the beta', 'Real users find the bugs unit tests never will.', 21, 'none',
    ['Pick three testers', 'Send the build', 'Collect a 10-minute call']],
  ['todo', 'Personal Projects', 'Build', 'low', 'Compress board screenshots for the store listing', 'PNG is 4 MB, the limit is 2.', 30, 'none',
    ['Downscale to 2x', 'Convert to WebP', 'Check the size']],
  ['todo', 'Self Care', 'Health', 'low', 'Stretching break every two hours', 'Three minutes at the desk between deep-work blocks.', 3, 'daily',
    ['Set a repeating timer', 'Pick three stretches', 'Log it for a week']],
  ['todo', 'Productivity', 'Design', 'low', 'Icons for the rule triggers', 'task_created, task_moved and friends need glyphs.', 22, 'none',
    ['Sketch six glyphs', 'Match the stroke weight', 'Wire them into the canvas']],
  ['todo', 'Personal Projects', 'Build', 'medium', 'Keyboard shortcuts for the board', 'j/k to move, x to complete, / to search.', 16, 'none',
    ['Map the shortcuts', 'Show them in a cheatsheet', 'Make them optional']],
  ['todo', 'Self Care', 'Care', 'low', 'Plan the weekend hike', 'Check the forecast first, pack the second pair of socks.', 9, 'none',
    ['Pick the trail', 'Check the weather', 'Charge the power bank']],
  ['todo', 'Productivity', 'Care', 'medium', 'Delete the two-year-old scratch tasks', 'The board has 40 cards nobody will ever touch.', 26, 'none',
    ['Filter untouched cards', 'Archive instead of delete', 'Keep three favorites']],
  ['todo', 'Personal Projects', 'Write', 'medium', 'Draft the architecture note', 'One page: how the client, API and database fit together.', 28, 'none',
    ['Draw the three boxes', 'Write the data flow', 'Get one review pass']],
  ['todo', 'Self Care', 'Ritual', 'medium', 'Call home this weekend', 'Thirty unhurried minutes.', 3, 'none',
    ['Pick a time', 'Put it in the calendar', 'No multitasking while talking']],
  ['todo', 'Productivity', 'Build', 'low', 'Fix the fold animation jank', 'The list jumps when a card is added mid-scroll.', 19, 'none',
    ['Profile the rebuild', 'Animate only the new card', 'Check on a mid-range phone']],
  ['todo', 'Personal Projects', 'Design', 'medium', 'Redo the store screen with real prices', 'Show what a theme costs next to what it does.', 24, 'none',
    ['Show prices in context', 'Grey out unaffordable themes', 'Keep the buy button obvious']],
  ['todo', 'Self Care', 'Care', 'low', 'Clear the photo library backlog', '4,812 screenshots, 12 keepers.', 17, 'none',
    ['Sort by screenshot', 'Keep the keepers', 'Empty the trash']],
  ['todo', 'Productivity', 'Product', 'high', 'Decide on sync conflict handling', 'Two devices, one task moved twice — which write wins?', 6, 'none',
    ['List the conflict cases', 'Pick last-write-wins or flag it', 'Write the rule down']],
  ['todo', 'Personal Projects', 'Build', 'low', 'Set up a nightly database backup', 'One file, one bucket, three weeks of retention.', 13, 'none',
    ['Dump to a file nightly', 'Upload to the bucket', 'Restore once to test']],
  ['todo', 'Self Care', 'Health', 'medium', 'Replace the desk chair', 'Back pain is the fee for the current one.', 33, 'none',
    ['Try three chairs', 'Spend an hour in each', 'Order the best one']],
  ['todo', 'Productivity', 'Design', 'low', 'Contrast pass on muted text', 'Some secondary text fails WCAG AA at small sizes.', 27, 'none',
    ['Audit every muted color', 'Darken where needed', 'Re-check the dark theme']],
];

// Long-tail filler so the count can be anything the caller asks for.
const FILLER_TAGS = ['Design', 'Build', 'Product', 'Care', 'Focus', 'Write'];
const FILLER_FOLDERS = ['Productivity', 'Personal Projects', 'Self Care'];
const FILLER_TITLES = [
  'Review the flow of an empty board',
  'Read through the notes from last sprint',
  'Tidy the tag list',
  'Try the new timer sound',
  'Check the heatmap against reality',
  'Rewrite one stale task title',
  'Archive a finished project folder',
  'Re-time the daily intention prompt',
  'Audit the notification copy',
  'Compare two card layouts side by side',
  'Clean up the folder icons',
  'Spot-check the dark theme on a projector',
  'Trim the seed data to a realistic size',
  'Write the fallback state for the store',
  'Check that due dates respect the timezone',
];
const fillerSteps = [
  'Write the first pass',
  'Ask for one round of feedback',
  'Ship it and move on',
];

const DAY_MS = DAY;
const buildTasks = (n) => {
  const out = [];
  for (let i = 0; i < n; i++) {
    const src = BLUEPRINT[i];
    if (src) {
      const [status, folder, tag, priority, title, description, dueIn, recurring, steps] = src;
      // Older tasks for finished work, recent ones for what is open.
      const age = status === 'done' ? 8 + ((i * 7) % 52) : status === 'in_progress' ? 1 + ((i * 3) % 14) : ((i * 5) % 40) + 1;
      out.push({
        status,
        folder,
        tag,
        priority,
        title,
        description,
        recurring,
        steps,
        createdAt: daysAgo(age),
        dueAt: dueIn ? new Date(NOW + dueIn * DAY_MS) : null,
        completedAt:
          status === 'done' ? new Date(NOW - (((i * 5) % Math.max(1, age)) + 0.5) * DAY_MS) : null,
      });
    } else {
      const j = i - BLUEPRINT.length;
      const folder = FILLER_FOLDERS[j % FILLER_FOLDERS.length];
      out.push({
        status: 'todo',
        folder,
        tag: FILLER_TAGS[j % FILLER_TAGS.length],
        priority: ['none', 'low', 'medium'][j % 3],
        title: `${FILLER_TITLES[j % FILLER_TITLES.length]} #${j + 1}`,
        description: 'Filler card so the board looks like a real week of work.',
        recurring: 'none',
        steps: fillerSteps.slice(0, 2 + (j % 2)),
        createdAt: daysAgo(1 + ((j * 4) % 35)),
        dueAt: null,
        completedAt: null,
      });
    }
  }
  return out;
};

// --- Firebase user --------------------------------------------------------

let userRecord = null;
try {
  userRecord = await auth.getUserByEmail(EMAIL);
  userRecord = await auth.updateUser(userRecord.uid, {
    password: PASSWORD,
    emailVerified: true,
    displayName: DISPLAY_NAME,
    disabled: false,
  });
  console.log('[firebase] updated existing user', userRecord.uid);
} catch (e) {
  if (e?.code !== 'auth/user-not-found') throw e;
  userRecord = await auth.createUser({
    email: EMAIL,
    password: PASSWORD,
    emailVerified: true,
    displayName: DISPLAY_NAME,
  });
  console.log('[firebase] created user', userRecord.uid);
}
const uid = userRecord.uid;

// --- DB row + defaults (same seeds firebase-sync applies) ------------------

const { rows: [user] } = await pool.query(
  `INSERT INTO users (email, display_name, avatar_label, active_theme, firebase_uid, created_at)
   VALUES ($1, $2, '桜', 'midnight', $3, now() - INTERVAL '60 days')
   ON CONFLICT (email) DO UPDATE
     SET firebase_uid = EXCLUDED.firebase_uid,
         display_name = EXCLUDED.display_name,
         avatar_label = EXCLUDED.avatar_label
   RETURNING id, email, firebase_uid`,
  [EMAIL, DISPLAY_NAME, uid],
);
const userId = user.id;

await pool.query(
  `INSERT INTO user_tokens (user_id, balance) VALUES ($1, 450)
   ON CONFLICT (user_id) DO UPDATE SET balance = 450`,
  [userId],
);
for (const theme of ['edo', 'midnight']) {
  await pool.query(
    'INSERT INTO owned_themes (user_id, theme_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
    [userId, theme],
  );
}
const { rows: ruleRows } = await pool.query(
  `INSERT INTO rules (user_id, name, trigger, condition, actions)
   VALUES ($1, 'Done → +10 tokens', 'task_done', '{}', $2)
   ON CONFLICT DO NOTHING RETURNING id`,
  [userId, JSON.stringify([{ type: 'award_tokens', amount: 10 }])],
);
if (!ruleRows.length) {
  await pool.query(
    `INSERT INTO rules (user_id, name, trigger, condition, actions)
     VALUES ($1, 'Focus done → inbox ping', 'focus_done', '{}', $2)`,
    [userId, JSON.stringify([{ type: 'inbox', title: 'Focus session finished', body: 'Nice work — log the result.' }])],
  );
}

// --- Wipe only this account's demo content, then rebuild -------------------

await pool.query('DELETE FROM tasks WHERE user_id = $1', [userId]); // cascades subtasks + events
await pool.query('DELETE FROM contributions WHERE user_id = $1', [userId]);
await pool.query('DELETE FROM folders WHERE user_id = $1', [userId]);

const folders = [
  ['Productivity', 'folder'],
  ['Self Care', 'heart'],
  ['Personal Projects', 'star'],
];
for (const [name, icon] of folders) {
  await pool.query(
    'INSERT INTO folders (user_id, name, icon) VALUES ($1, $2, $3)',
    [userId, name, icon],
  );
}

const AVATARS = ['禅', '和', '桜', '集中', '静', '朝', '建', '掃'];
const tasks = buildTasks(TASK_COUNT);
const positionByStatus = { todo: 0, in_progress: 0, done: 0 };
const subtaskRows = [];
const eventRows = [];
let subCount = 0;
let evCount = 0;

for (const t of tasks) {
  const position = positionByStatus[t.status]++;
  const avatar = AVATARS[position % AVATARS.length];
  const { rows } = await pool.query(
    `INSERT INTO tasks (title, tag, status, folder, avatar_label, description, priority,
                        recurring, position, created_at, due_at, completed_at, user_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id`,
    [t.title, t.tag, t.status, t.folder, avatar, t.description, t.priority,
     t.recurring, position, t.createdAt, t.dueAt, t.completedAt, userId],
  );
  const id = rows[0].id;

  // Subtasks: done work is fully checked, in-progress is part-way, todo is open.
  const doneCount =
    t.status === 'done' ? t.steps.length : t.status === 'in_progress' ? Math.min(1, t.steps.length) : 0;
  t.steps.forEach((title, i) => {
    const done = i < doneCount;
    const completedAt = done
      ? new Date(t.completedAt ?? t.createdAt.getTime() + (i + 1) * 6 * 3600 * 1000)
      : null;
    subtaskRows.push([id, title, done, i, t.createdAt, completedAt]);
    if (done) {
      eventRows.push([id, userId, 'subtask', null, 'done', title, completedAt]);
    }
  });
  subCount += t.steps.length;

  // History so timelines / activity / the History tab are not empty.
  eventRows.push([id, userId, 'created', null, 'todo', '', t.createdAt]);
  if (t.status === 'done') {
    const mid = new Date((t.createdAt.getTime() + t.completedAt.getTime()) / 2);
    eventRows.push([id, userId, 'status', 'todo', 'in_progress', '', mid]);
    eventRows.push([id, userId, 'status', 'in_progress', 'done', '', t.completedAt]);
  } else if (t.status === 'in_progress') {
    eventRows.push([id, userId, 'status', 'todo', 'in_progress', '', new Date(t.createdAt.getTime() + DAY_MS)]);
  }
  evCount += 1;
}

// One standup note on a handful of in-progress cards.
for (const t of tasks.filter((x) => x.status === 'in_progress').slice(0, 4)) {
  const { rows } = await pool.query('SELECT id FROM tasks WHERE user_id = $1 AND title = $2', [userId, t.title]);
  if (rows.length) {
    eventRows.push([rows[0].id, userId, 'note', null, null, 'Blocked on review — picked it back up today.', new Date(NOW - 2 * DAY_MS)]);
    evCount += 1;
  }
}

const chunkInsert = async (sql, rows, width) => {
  for (let i = 0; i < rows.length; i += 200) {
    const slice = rows.slice(i, i + 200);
    const values = [];
    const placeholders = slice
      .map((row) => {
        const base = values.length;
        for (const v of row) values.push(v);
        return `(${Array.from({ length: width }, (_, k) => `$${base + k + 1}`).join(',')})`;
      })
      .join(',');
    await pool.query(`${sql} VALUES ${placeholders}`, values);
  }
};

await chunkInsert(
  'INSERT INTO subtasks (task_id, title, done, position, created_at, completed_at)',
  subtaskRows,
  6,
);
await chunkInsert(
  'INSERT INTO task_events (task_id, user_id, kind, from_status, to_status, body, created_at)',
  eventRows,
  7,
);

// --- Heatmap activity -----------------------------------------------------
// Completed work counts itself; a sparse filler of extra active days keeps
// the 12-week grid looking lived-in and gives a real current streak.
const contributions = new Map();
const bump = (day, n) => {
  const key = day.toISOString().slice(0, 10);
  contributions.set(key, (contributions.get(key) ?? 0) + n);
};
for (const t of tasks) {
  if (t.completedAt) bump(t.completedAt, 1 + (t.title.length % 3));
}
for (let i = 0; i < 84; i++) {
  if (i % 9 === 3 || i % 13 === 5) bump(daysAgo(i), 1 + (i % 2));
}
if (!contributions.has(new Date(NOW).toISOString().slice(0, 10))) bump(new Date(NOW), 2);

const contribRows = [...contributions.entries()].map(([day, count]) => [userId, day, count]);
await chunkInsert('INSERT INTO contributions (user_id, day, count)', contribRows, 3);

const summary = await pool.query(
  `SELECT
     (SELECT COUNT(*)::int FROM tasks WHERE user_id = $1) AS tasks,
     (SELECT COUNT(*)::int FROM subtasks s JOIN tasks t ON s.task_id = t.id
        WHERE t.user_id = $1) AS subtasks,
     (SELECT MIN(c)::int FROM (SELECT COUNT(*) c FROM subtasks s JOIN tasks t ON s.task_id = t.id
        WHERE t.user_id = $1 GROUP BY s.task_id) x) AS min_subs,
     (SELECT MAX(c)::int FROM (SELECT COUNT(*) c FROM subtasks s JOIN tasks t ON s.task_id = t.id
        WHERE t.user_id = $1 GROUP BY s.task_id) x) AS max_subs,
     (SELECT COUNT(*)::int FROM task_events WHERE user_id = $1) AS events,
     (SELECT COUNT(*)::int FROM contributions WHERE user_id = $1) AS active_days`,
  [userId],
);

console.log(JSON.stringify(
  {
    email: EMAIL,
    password: PASSWORD,
    firebaseUid: uid,
    userId,
    api: API_URL,
    seeded: { ...summary.rows[0] },
    byStatus: tasks.reduce((acc, t) => ({ ...acc, [t.status]: (acc[t.status] ?? 0) + 1 }), {}),
  },
  null,
  1,
));

await pool.end();
