// Level + streak math shared by heatmap, progress, and insights.
// Moved verbatim from src/index.js (route split). No logic changes.

export const levelFor = (count) => {
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
export function streakStats(dayCounts, windowDays) {
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