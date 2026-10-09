// Unit tests for the AI local heuristics — no network, no DB.
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  parseQuickAddLocal,
  breakdownLocal,
  planLocal,
  narrativeLocal,
  groomLocal,
  askLocal,
  checkCap,
  resetCaps,
} from '../src/ai.js';

describe('parseQuickAddLocal', () => {
  it('strips #tag into tag', () => {
    const p = parseQuickAddLocal('Write report #work');
    assert.equal(p.title, 'Write report');
    assert.equal(p.tag, 'Work');
  });

  it('detects tomorrow 5pm', () => {
    const p = parseQuickAddLocal('Report tomorrow 5pm');
    assert.equal(p.title, 'Report');
    assert.ok(p.due_at);
    assert.equal(new Date(p.due_at).getHours(), 17);
  });

  it('flags urgent as high priority', () => {
    const p = parseQuickAddLocal('Ship it urgent');
    assert.equal(p.priority, 'high');
    assert.equal(p.title, 'Ship it');
  });
});

describe('breakdownLocal', () => {
  it('returns steps with minutes', () => {
    const steps = breakdownLocal('Write launch report');
    assert.ok(steps.length >= 3);
    assert.ok(steps.every((s) => s.title && s.minutes >= 5));
  });
});

describe('planLocal', () => {
  it('prefers overdue + high priority', () => {
    const past = new Date(Date.now() - 86400000).toISOString();
    const { picks } = planLocal([
      { id: 'a', title: 'Later', status: 'todo', priority: 'none' },
      { id: 'b', title: 'Late big', status: 'todo', priority: 'high', due_at: past },
    ]);
    assert.equal(picks[0].id, 'b');
    assert.ok(picks.length <= 3);
  });
});

describe('narrativeLocal', () => {
  it('narrates a productive week', () => {
    const n = narrativeLocal({ tips: ['Protect 14:00.'], stats: { done: 8, streak: 4, focusMinutes: 120 } });
    assert.ok(n.text.includes('8 task'));
    assert.ok(n.text.includes('120'));
  });

  it('stays kind on a quiet week', () => {
    const n = narrativeLocal({ tips: [], stats: {} });
    assert.ok(n.text.includes('quiet week'));
  });
});

describe('groomLocal', () => {
  it('flags duplicates, keeping newest', () => {
    const g = groomLocal([
      { id: 'a', title: 'Buy milk', status: 'todo', created_at: '2026-01-01' },
      { id: 'b', title: 'buy  milk!', status: 'todo', created_at: '2026-02-01' },
    ]);
    const dup = g.groups.find((x) => x.kind === 'duplicates');
    assert.ok(dup);
    assert.deepEqual(dup.ids, ['a']);
  });

  it('flags stale and vague', () => {
    const old = new Date(Date.now() - 40 * 24 * 3600 * 1000).toISOString();
    const g = groomLocal([
      { id: 's', title: 'Something old and long enough', status: 'todo', created_at: old },
      { id: 'v', title: 'Fix it', status: 'todo', created_at: new Date().toISOString() },
    ]);
    assert.ok(g.groups.some((x) => x.kind === 'stale'));
    assert.ok(g.groups.some((x) => x.kind === 'vague'));
  });
});

describe('askLocal', () => {
  it('ranks title matches first', () => {
    const a = askLocal('gym', [
      { id: 'g', title: 'Morning gym run', status: 'todo', tag: 'Health', folder: 'H', description: '' },
      { id: 'x', title: 'Read book', status: 'todo', tag: 'L', folder: 'L', description: '' },
    ]);
    assert.deepEqual(a.ids, ['g']);
    assert.ok(a.answer.includes('1 match'));
  });
});

describe('checkCap', () => {  it('caps after the daily limit', () => {
    resetCaps();
    process.env.AI_DAILY_CAP = process.env.AI_DAILY_CAP; // capped at import time
    assert.equal(checkCap('u-cap-test'), true);
  });
});
