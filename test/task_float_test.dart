import 'package:daily_bloom/data/api_client.dart';
import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// M3.3 + M4.2: urgent float ordering and the subtask accordion.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('floatUrgent bands overdue, today, rest — stable inside bands', () {
    final now = DateTime(2026, 10, 9, 12);
    final overdue = Task(
        id: 'o', title: 'Late', tag: 'G', dueAt: DateTime(2026, 10, 7, 9));
    final today = Task(
        id: 't', title: 'Today', tag: 'G', dueAt: DateTime(2026, 10, 9, 18));
    const first = Task(id: 'a', title: 'A', tag: 'G');
    const second = Task(id: 'b', title: 'B', tag: 'G');
    final done = Task(
        id: 'd',
        title: 'Done',
        tag: 'G',
        status: 'done',
        dueAt: DateTime(2026, 10, 1));
    final out =
        floatUrgent([first, today, second, overdue, done], now);
    expect(out.map((t) => t.id).toList(), ['o', 't', 'a', 'b', 'd']);
    expect(isOverdue(overdue, now), isTrue);
    expect(isDueToday(today, now), isTrue);
    expect(isDueToday(overdue, now), isFalse);
    expect(isOverdue(done, now), isFalse);
  });

  testWidgets('cards with 3+ subtasks collapse behind a badge', (tester) async {
    final task = Task(id: 't', title: 'Big', tag: 'G', subtasks: [
      Subtask(
          id: 's1',
          taskId: 't',
          title: 'One',
          done: true,
          startedAt: DateTime(2026, 10, 1)),
      Subtask(
          id: 's2',
          title: 'Two',
          taskId: 't',
          startedAt: DateTime(2026, 10, 1)),
      Subtask(
          id: 's3',
          title: 'Three',
          taskId: 't',
          startedAt: DateTime(2026, 10, 1)),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TaskCard(task: task))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Badge shows progress ([Show]), full rows stay hidden.
    expect(find.text('[Show]'), findsOneWidget);
    expect(find.text('Three'), findsNothing);
    // Tap expands inline.
    await tester.tap(find.text('[Show]'));
    await tester.pump();
    expect(find.text('Three'), findsOneWidget);
    expect(find.text('[Hide]'), findsOneWidget);
  });

  testWidgets('cards with 2 subtasks render fully, no badge', (tester) async {
    final task = Task(id: 't', title: 'Small', tag: 'G', subtasks: [
      Subtask(
          id: 's1',
          title: 'One',
          taskId: 't',
          startedAt: DateTime(2026, 10, 1)),
      Subtask(
          id: 's2',
          title: 'Two',
          taskId: 't',
          startedAt: DateTime(2026, 10, 1)),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: TaskCard(task: task))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('[Show]'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
  });
}
