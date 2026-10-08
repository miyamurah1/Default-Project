// Phase A model tests — pure JSON parsing, no platform channels needed.

import 'package:flutter_test/flutter_test.dart';

import 'package:daily_bloom/data/api_client.dart';
import 'package:daily_bloom/data/focus_controller.dart' show formatCountdown;
import 'package:daily_bloom/data/mock_data.dart';

void main() {
  test('nextStatus resumes to progress, completes to done', () {
    const todo = Task(id: 't', title: 'T', tag: 'G', status: 'todo');
    const prog = Task(id: 'p', title: 'P', tag: 'G', status: 'in_progress');
    const done = Task(id: 'd', title: 'D', tag: 'G', status: 'done');
    expect(nextStatus(todo), 'done');
    expect(nextStatus(prog), 'done');
    // Reopening resumes work — never back to the To-Do pile.
    expect(nextStatus(done), 'in_progress');
  });
  test('TaskEvent parses a status move', () {
    final e = TaskEvent.fromJson({
      'id': 'e1',
      'task_id': 't1',
      'kind': 'status',
      'from_status': 'todo',
      'to_status': 'done',
      'body': '',
      'created_at': '2026-09-21T10:00:00.000Z',
    });
    expect(e.kind, 'status');
    expect(e.fromStatus, 'todo');
    expect(e.toStatus, 'done');
    expect(e.taskTitle, isNull);
    expect(e.createdAt.year, 2026);
  });

  test('TaskEvent parses activity rows with task title', () {
    final e = TaskEvent.fromJson({
      'id': 'e2',
      'task_id': 't2',
      'kind': 'note',
      'from_status': null,
      'to_status': null,
      'body': 'Started working on it',
      'task_title': 'My task',
      'created_at': '2026-09-21T10:00:00.000Z',
    });
    expect(e.body, 'Started working on it');
    expect(e.taskTitle, 'My task');
  });

  test('Subtask parses bool + string done, defaults position', () {
    final a = Subtask.fromJson({
      'id': 's1',
      'task_id': 't1',
      'title': 'Step one',
      'done': true,
    });
    expect(a.done, isTrue);
    expect(a.position, 0);

    final b = Subtask.fromJson({
      'id': 's2',
      'task_id': 't1',
      'title': 'Step two',
      'done': 'false',
      'position': 3,
    });
    expect(b.done, isFalse);
    expect(b.position, 3);
  });

  test('Subtask.copyWith flips done only', () {
    final s = Subtask(
        id: 's',
        taskId: 't',
        title: 'x',
        done: false,
        position: 1,
        startedAt: DateTime(2026, 9, 30));
    final flipped = s.copyWith(done: true);
    expect(flipped.done, isTrue);
    expect(flipped.title, 'x');
    expect(flipped.position, 1);
    expect(flipped.startedAt, DateTime(2026, 9, 30));
    expect(flipped.completedAt, isNull);
  });

  test('Subtask parses started/completed dates', () {
    final s = Subtask.fromJson({
      'id': 's3',
      'task_id': 't1',
      'title': 'Step three',
      'done': true,
      'created_at': '2026-09-30T09:00:00.000Z',
      'completed_at': '2026-10-01T10:00:00.000Z',
    });
    expect(s.startedAt, DateTime.utc(2026, 9, 30, 9));
    expect(s.completedAt, DateTime.utc(2026, 10, 1, 10));
  });

  test('taskElapsed measures created -> done, live while open', () {
    final created = DateTime.utc(2026, 9, 30, 9);
    final done = Task(
      id: 't1',
      title: 'Ship it',
      tag: 'Design',
      createdAt: created,
      completedAt: DateTime.utc(2026, 9, 30, 11, 30),
    );
    expect(taskElapsed(done), const Duration(hours: 2, minutes: 30));

    // Open task: elapsed keeps growing against the injected clock.
    final open = Task(
        id: 't2', title: 'Draft it', tag: 'Design', createdAt: created);
    expect(taskElapsed(open, DateTime.utc(2026, 9, 30, 9, 45)),
        const Duration(minutes: 45));

    // No created_at (offline mocks) -> nothing to measure.
    expect(taskElapsed(const Task(id: 't3', title: 'x', tag: 'y')), isNull);
  });

  test('fmtElapsed reads as minutes, hours, then days', () {
    expect(fmtElapsed(const Duration(minutes: 12)), '12m');
    expect(fmtElapsed(const Duration(hours: 3, minutes: 12)), '3h 12m');
    expect(fmtElapsed(const Duration(hours: 3)), '3h');
    expect(fmtElapsed(const Duration(days: 2, hours: 4)), '2d 4h');
    expect(fmtElapsed(const Duration(days: 2)), '2d');
  });

  test('FlowRule parses condition + actions', () {
    final r = FlowRule.fromJson({
      'id': 'r1',
      'name': 'Done → party',
      'enabled': true,
      'trigger': 'task_done',
      'condition': {'field': 'tag', 'op': 'equals', 'value': 'Design'},
      'actions': [
        {'type': 'award_tokens', 'amount': 10},
        {'type': 'inbox', 'title': 'Nice', 'body': 'Well done'}
      ],
      'created_at': '2026-09-21T10:00:00.000Z',
    });
    expect(r.enabled, isTrue);
    expect(r.condition['field'], 'tag');
    expect(r.actions.length, 2);
    expect(actionLabel(r.actions[0]), '+10 tokens');
    expect(triggerLabel('task_done'), 'Task completed');
  });

  test('FlowRule tolerates empty condition and string bools', () {
    final r = FlowRule.fromJson({
      'id': 'r2',
      'name': 'Always',
      'enabled': 'false',
      'trigger': 'task_created',
      'condition': {},
      'actions': [
        {'type': 'move_task', 'status': 'in_progress'}
      ],
      'created_at': '2026-09-21T10:00:00.000Z',
    });
    expect(r.enabled, isFalse);
    expect(r.condition, isEmpty);
    expect(actionLabel(r.actions[0]), 'Move to In Progress');
  });

  test('RuleRun parses a skipped run', () {
    final run = RuleRun.fromJson({
      'id': 'run1',
      'rule_id': 'r1',
      'task_id': 't1',
      'task_title': 'My task',
      'status': 'skipped',
      'detail': {'reason': 'condition did not match'},
      'created_at': '2026-09-21T10:00:00.000Z',
    });
    expect(run.status, 'skipped');
    expect(run.taskTitle, 'My task');
    expect(run.detail['reason'], 'condition did not match');
  });

  test('InboxMessage parses unread flags', () {
    final m = InboxMessage.fromJson({
      'id': 'm1',
      'tag': 'AUTOMATION',
      'title': 'Hello',
      'body': 'World',
      'unread': true,
      'created_at': '2026-09-21T10:00:00.000Z',
    });
    expect(m.unread, isTrue);
    expect(m.tag, 'AUTOMATION');
  });

  test('FocusSession parses a finished session', () {
    final s = FocusSession.fromJson({
      'id': 'f1',
      'task_id': 't1',
      'mode': 'focus',
      'planned_minutes': 25,
      'actual_minutes': 25,
      'completed': true,
      'started_at': '2026-09-21T10:00:00.000Z',
    });
    expect(s.completed, isTrue);
    expect(s.plannedMinutes, 25);
    expect(s.startedAt.year, 2026);
  });

  test('FocusHistory parses totals', () {
    final h = FocusHistory.fromJson({
      'sessions': [],
      'totals': {'sessions': 3, 'minutes': 70, 'completed': 2},
    });
    expect(h.totalSessions, 3);
    expect(h.totalMinutes, 70);
    expect(h.completedCount, 2);
  });

  test('formatCountdown pads mm:ss', () {
    expect(formatCountdown(const Duration(minutes: 25)), '25:00');
    expect(formatCountdown(const Duration(minutes: 4, seconds: 5)), '04:05');
    expect(formatCountdown(const Duration(seconds: -3)), '00:00');
  });

  Insights sampleInsights() => const Insights(
        byTag: [
          SplitStat(name: 'Design', total: 4, done: 4),
          SplitStat(name: 'Product', total: 4, done: 1),
        ],
        cycleN: 3,
        cycleMedianHours: 26.5,
        hours: [
          {'h': 9, 'n': 1},
          {'h': 14, 'n': 3},
        ],
        focusMinutes7: 120,
        focusSessions7: 5,
        streakBest30: 6,
        streakCurrent: 3,
      );

  test('buildInsights narrates strengths, cycle, peak hour', () {
    final tips = buildInsights(sampleInsights());
    expect(tips.any((t) => t.contains('63%')), isTrue);
    expect(tips.any((t) => t.contains('Design') && t.contains('Product')),
        isTrue);
    expect(tips.any((t) => t.contains('14:00')), isTrue);
    expect(tips.any((t) => t.contains('120 min')), isTrue);
  });

  test('buildInsights handles an empty account', () {
    final tips = buildInsights(const Insights());
    expect(tips.length, 1);
    expect(tips.first, contains('patterns will appear'));
  });
}
