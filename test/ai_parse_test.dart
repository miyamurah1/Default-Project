import 'package:daily_bloom/data/ai_client.dart';
import 'package:daily_bloom/data/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse strips hashtag into tag', () {
    final p = parseQuickAddLocal('Write report #work');
    expect(p.title, 'Write report');
    expect(p.tag, 'Work');
  });

  test('parse detects tomorrow + time', () {
    final p = parseQuickAddLocal('Report tomorrow 5pm');
    expect(p.title, 'Report');
    expect(p.dueAt, isNotNull);
    expect(p.dueAt!.hour, 17);
  });

  test('parse flags high priority', () {
    final p = parseQuickAddLocal('Ship it urgent');
    expect(p.priority, 'high');
    expect(p.title, 'Ship it');
  });

  test('breakdown returns usable steps', () {
    final steps = breakdownLocal('Write launch report');
    expect(steps.length, greaterThanOrEqualTo(3));
    expect(steps.every((s) => s.title.isNotEmpty), isTrue);
  });

  test('planner prefers overdue + high priority', () {
    final past = DateTime.now().subtract(const Duration(days: 1));
    final picks = planDayLocal([
      const Task(id: 'a', title: 'Later', tag: 'G'),
      Task(id: 'b', title: 'Late big', tag: 'G', priority: 'high', dueAt: past),
    ]);
    expect(picks.first.id, 'b');
    expect(picks.length, lessThanOrEqualTo(3));
  });

  test('narrative stays kind when quiet', () {
    final text = narrativeLocal(const [], done: 0, streak: 0, focusMinutes: 0);
    expect(text, contains('quiet week'));
    final good = narrativeLocal(const ['Protect 14:00.'],
        done: 8, streak: 4, focusMinutes: 120);
    expect(good, contains('8 task'));
  });

  test('groom flags duplicates and vague', () {
    final groups = groomLocal([
      const Task(id: 'a', title: 'Buy milk', tag: 'G'),
      const Task(id: 'b', title: 'buy  milk!', tag: 'G'),
      const Task(id: 'v', title: 'Fix it', tag: 'G'),
    ]);
    expect(groups.any((g) => g.kind == 'duplicates'), isTrue);
    expect(groups.any((g) => g.kind == 'vague'), isTrue);
  });

  test('ask ranks title matches first', () {
    final answer = askLocal('gym', [
      const Task(id: 'g', title: 'Morning gym run', tag: 'Health'),
      const Task(id: 'x', title: 'Read book', tag: 'L'),
    ]);
    expect(answer.ids, ['g']);
    expect(answer.text, contains('1 match'));
  });

  test('non-Latin input is flagged as unsupported for AI', () {
    expect(isAiSupportedScript('Report tomorrow 5pm'), isTrue);
    expect(isAiSupportedScript(''), isTrue);
    expect(isAiSupportedScript('ಕಲ ರಿಪೋರ್ಟ್'), isFalse);
    expect(isAiSupportedScript('明日の会議の準備'), isFalse);
    expect(isAiSupportedScript('تقرير غدا'), isFalse);
  });

  test('load bar totals open subtasks, else one block', () {
    const t = Task(id: 'a', title: 'Big', tag: 'G');
    expect(estimatedMinutes(t), 25);
    expect(fmtLoad(25), '25m');
    expect(fmtLoad(130), '2h 10m');
  });

  test('repeat candidates need 2+ dones and no recurrence', () {
    const open = [
      Task(id: 'o1', title: 'Morning run', tag: 'H'),
      Task(id: 'o2', title: 'Weekly sync', tag: 'W', recurring: 'weekly'),
    ];
    const done = [
      Task(id: 'd1', title: 'morning RUN!', tag: 'H', status: 'done'),
      Task(id: 'd2', title: 'Morning run', tag: 'H', status: 'done'),
      Task(id: 'd3', title: 'Weekly sync', tag: 'W', status: 'done'),
      Task(id: 'd4', title: 'Weekly sync', tag: 'W', status: 'done'),
    ];
    final cands = repeatCandidates(open, done);
    expect(cands.length, 1);
    expect(cands.first.task.id, 'o1');
    expect(cands.first.times, 2);
  });
}
