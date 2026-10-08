import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/widgets/task_card.dart';
import 'package:daily_bloom/widgets/timeline_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('label words a finished span: created · done · took', () {
    expect(
      TimelineRail.label(
        created: DateTime(2026, 9, 29, 10),
        completed: DateTime(2026, 10, 1, 11),
      ),
      'created Sep 29 · done Oct 1 · 2d 1h',
    );
  });

  test('label keeps counting while open, and clamps a broken pair', () {
    final created = DateTime(2026, 9, 29, 10);
    expect(
      TimelineRail.label(
          created: created, now: DateTime(2026, 9, 29, 10, 45)),
      'created Sep 29 · running 45m',
    );
    // Completed before created (clock skew) never goes negative.
    expect(
      TimelineRail.label(
          created: created, completed: DateTime(2026, 9, 29, 9)),
      'created Sep 29 · done Sep 29 · 0m',
    );
  });

  test('span measures completed - created, else now - created', () {
    final created = DateTime(2026, 9, 29, 8);
    expect(
      TimelineRail.span(
          created: created, completed: DateTime(2026, 9, 29, 10)),
      const Duration(hours: 2),
    );
    expect(
      TimelineRail.span(created: created, now: DateTime(2026, 9, 29, 9, 30)),
      const Duration(hours: 1, minutes: 30),
    );
  });

  test('a due date is a deadline, not an end', () {
    final created = DateTime(2026, 9, 29, 9);
    final t = Task(
      id: 't1',
      title: 'Ship it',
      tag: 'Design',
      createdAt: created,
      dueAt: DateTime(2026, 10, 9, 9), // future deadline
    );
    // Used to clamp to 0m by measuring up to the (future) due date.
    expect(taskElapsed(t, DateTime(2026, 9, 29, 12)),
        const Duration(hours: 3));
  });

  testWidgets('rail draws the line, and adds nothing when untimed',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TimelineRail(
          created: DateTime(2026, 9, 29, 10),
          completed: DateTime(2026, 10, 1, 11),
          done: true,
        ),
      ),
    ));
    expect(find.text('created Sep 29 · done Oct 1 · 2d 1h'), findsOneWidget);

    // No created_at (offline/mock rows) -> zero pixels, no placeholder.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TimelineRail(created: null, done: false)),
    ));
    expect(tester.getSize(find.byType(TimelineRail)), Size.zero);
    expect(find.textContaining('created'), findsNothing);
  });

  testWidgets('home card grows the rail only for stamped tasks',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TaskCard(task: Task(id: 't1', title: 'Draft it', tag: 'Design')),
      ),
    ));
    // Untimed task (mock/offline): the card skips the rail entirely.
    expect(find.byType(TimelineRail), findsNothing);
    expect(find.textContaining('created '), findsNothing);

    final stamped = Task(
      id: 't2',
      title: 'Ship it',
      tag: 'Design',
      status: 'done',
      createdAt: DateTime(2026, 9, 29, 10),
      completedAt: DateTime(2026, 10, 1, 11),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TaskCard(task: stamped)),
    ));
    expect(find.text('created Sep 29 · done Oct 1 · 2d 1h'), findsOneWidget);
  });
}
