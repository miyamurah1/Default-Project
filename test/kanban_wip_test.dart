import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/widgets/kanban_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Task> _tasks(String prefix, int n, {String status = 'todo'}) =>
    List.generate(
        n,
        (i) => Task(
            id: '$prefix$i', title: 'T$i', tag: 'General', status: status));

Future<void> _pump(
    WidgetTester tester, double w, KanbanBoard board) async {
  SharedPreferences.setMockInitialValues({});
  addTearDown(() {
    SharedPreferences.setMockInitialValues({});
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: board)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

KanbanBoard _board(int progressCount) => KanbanBoard(
      todo: _tasks('t', 1),
      progress: _tasks('p', progressCount, status: 'in_progress'),
      done: const [],
      onTap: (_) {},
      onOpen: (_) {},
      onToggleSub: (_, __) {},
      onTimer: (_) {},
    );

void main() {
  test('overWip trips above 3', () {
    expect(KanbanBoard.wipLimit, 3);
    expect(KanbanBoard.overWip(2), isFalse);
    expect(KanbanBoard.overWip(3), isFalse);
    expect(KanbanBoard.overWip(4), isTrue);
  });

  testWidgets('wide board signals 4/3 with the calm line', (tester) async {
    await _pump(tester, 1400, _board(4));
    expect(tester.takeException(), isNull);
    expect(find.text('4/3'), findsOneWidget);
    expect(
        find.text(
            'Over the limit — finish one before starting more.'),
        findsOneWidget);
  });

  testWidgets('wide board stays quiet at limit', (tester) async {
    await _pump(tester, 1400, _board(2));
    expect(tester.takeException(), isNull);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('2/3'), findsNothing);
    expect(
        find.text(
            'Over the limit — finish one before starting more.'),
        findsNothing);
  });

  testWidgets('narrow tabs signal on the progress tab', (tester) async {
    await _pump(
        tester,
        390,
        KanbanBoard(
          todo: _tasks('t', 1),
          progress: _tasks('p', 5, status: 'in_progress'),
          done: const [],
          onTap: (_) {},
          onOpen: (_) {},
          onToggleSub: (_, __) {},
          onTimer: (_) {},
          tabsOnly: true,
        ));
    expect(tester.takeException(), isNull);
    expect(find.text('PROGRESS (5/3)'), findsOneWidget);
    await tester.tap(find.text('PROGRESS (5/3)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.text(
            'Over the limit — finish one before starting more.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
