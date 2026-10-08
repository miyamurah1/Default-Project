import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/screens/app_shell.dart';
import 'package:daily_bloom/screens/habits_screen.dart';
import 'package:daily_bloom/screens/home_screen.dart';
import 'package:daily_bloom/widgets/daily_intention_card.dart';
import 'package:daily_bloom/widgets/sakura_bottom_nav.dart';
import 'package:daily_bloom/widgets/task_flow_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Responsive audit: every primary surface must lay out with zero
/// overflow from small phones (360) through desktop (1400).
/// Uses plain pumps (never settle — glow controllers never settle)
/// and asserts no exception was recorded while laying out.
Future<void> _pumpAt(
    WidgetTester tester, double width, Widget home) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(home: home));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  group('Home responsive', () {
    for (final w in [360.0, 390.0]) {
      testWidgets('mobile ${w.toInt()}px: unified slivers, no overflow',
          (tester) async {
        await _pumpAt(tester, w, const HomeScreen());
        expect(tester.takeException(), isNull);
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    }
    for (final w in [700.0, 1400.0]) {
      testWidgets('desktop ${w.toInt()}px: stacked bar, no overflow',
          (tester) async {
        await _pumpAt(tester, w, const HomeScreen());
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        // One stacked navbar on every width — same bar as mobile.
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      });
    }

    testWidgets('embedded home hides section nav (AppShell owns it)',
        (tester) async {
      await _pumpAt(tester, 1400, const HomeScreen(embedded: true));
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });
  });

  group('Habits responsive', () {
    for (final w in [360.0, 390.0]) {
      testWidgets('no overflow at ${w.toInt()}px', (tester) async {
        await _pumpAt(tester, w, const HabitsScreen());
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AppShell responsive', () {
    testWidgets('mobile 390: bottom nav, no overflow', (tester) async {
      await _pumpAt(tester, 390, const AppShell());
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop 1100: stacked bar, no overflow', (tester) async {
      await _pumpAt(tester, 1100, const AppShell());
      expect(tester.takeException(), isNull);
      expect(find.byType(SakuraBottomNav), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  testWidgets('DailyIntentionCard fits 360px phones', (tester) async {
    await _pumpAt(
        tester, 360, const Scaffold(body: DailyIntentionCard()));
    expect(tester.takeException(), isNull);
    expect(find.text("Today's focus"), findsOneWidget);
  });

  group('Task tabs sizing', () {
    testWidgets('section height follows the selected tab, not the tallest',
        (tester) async {
      const todo = [
        Task(id: 't1', title: 'One thing', tag: 'General')
      ];
      final done = List.generate(
          9,
          (i) => Task(
              id: 'd$i',
              title: 'Done $i',
              tag: 'General',
              status: 'done'));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TaskFlowList(
        todo: todo,
        progress: const [],
        done: done,
        onTap: (_) {},
        onOpen: (_) {},
        onToggleSub: (_, __) {},
        onTimer: (_) {},
      )))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final shortH = tester.getSize(find.byType(TaskFlowList)).height;
      // Switch to the 9-task DONE tab: the section must grow with it…
      await tester.tap(find.text('DONE (9)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final tallH = tester.getSize(find.byType(TaskFlowList)).height;
      expect(tallH, greaterThan(shortH + 200));
      // …and shrink straight back when returning to the short tab,
      // leaving no dead space behind.
      await tester.tap(find.text('TO-DO (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TaskFlowList)).height, shortH);
    });
  });
}
