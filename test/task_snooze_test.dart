import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/screens/task_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Task task) async {
  SharedPreferences.setMockInitialValues({});
  addTearDown(() => SharedPreferences.setMockInitialValues({}));
  await tester.pumpWidget(MaterialApp(home: TaskDetailScreen(task: task)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

Task _task({required String id, DateTime? dueAt, String status = 'todo'}) =>
    Task(id: id, title: 'T', tag: 'General', status: status, dueAt: dueAt);

void main() {
  testWidgets('overdue open task offers Tomorrow', (tester) async {
    await _pump(tester,
        _task(id: 't1', dueAt: DateTime.now().subtract(const Duration(days: 2))));
    expect(tester.takeException(), isNull);
    expect(find.text('Tomorrow'), findsOneWidget);
  });

  testWidgets('future-dated task hides the pill', (tester) async {
    await _pump(tester,
        _task(id: 't2', dueAt: DateTime.now().add(const Duration(days: 9))));
    expect(tester.takeException(), isNull);
    expect(find.text('Tomorrow'), findsNothing);
    expect(find.textContaining('Due '), findsOneWidget);
  });

  testWidgets('done task hides the pill', (tester) async {
    await _pump(
        tester,
        _task(
            id: 't3',
            status: 'done',
            dueAt: DateTime.now().subtract(const Duration(days: 2))));
    expect(tester.takeException(), isNull);
    expect(find.text('Tomorrow'), findsNothing);
  });

  testWidgets('offline tap snoozes optimistically (no dead-end)',
      (tester) async {
    await _pump(tester,
        _task(id: 't4', dueAt: DateTime.now().subtract(const Duration(days: 1))));
    // Let the load-failure snackbar expire so it can't eat the tap.
    await tester.pump(const Duration(seconds: 5));
    await tester.scrollUntilVisible(
      find.text('Tomorrow'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tomorrow'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    // Offline-first: the date moves immediately and offers Undo instead
    // of a "connect and retry" dead-end.
    expect(find.textContaining('Snoozed →'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
}
