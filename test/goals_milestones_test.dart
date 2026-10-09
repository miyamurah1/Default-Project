import 'package:daily_bloom/data/goal_store.dart';
import 'package:daily_bloom/screens/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => GoalStore.instance.debugFill());

  test('goal progress derives from checked milestones', () {
    final goal = ProjectGoal(
      id: 'g',
      title: 'Ship',
      createdAt: DateTime(2026, 1, 1),
      milestones: const [],
    );
    expect(goal.progress, 0);
    expect(goal.daysRemaining(), isNull);
  });

  test('daysRemaining counts whole days, negative when overdue', () {
    final now = DateTime.now();
    final future = ProjectGoal(
      id: 'g',
      title: 'X',
      targetDate: DateTime(now.year, now.month, now.day + 5),
      createdAt: now,
    );
    expect(future.daysRemaining(now), 5);
    final past = ProjectGoal(
      id: 'g2',
      title: 'Y',
      targetDate: DateTime(now.year, now.month, now.day - 2),
      createdAt: now,
    );
    expect(past.daysRemaining(now), -2);
  });

  testWidgets('GoalsScreen shows milestones, toggles update progress',
      (tester) async {
    GoalStore.instance.debugFill([
      ProjectGoal(
        id: 'g1',
        title: 'Launch V1 Beta',
        targetDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
        milestones: const [
          GoalMilestone(id: 'm1', title: 'Draft specs', done: true),
          GoalMilestone(id: 'm2', title: 'Build prototype'),
          GoalMilestone(id: 'm3', title: 'User testing'),
        ],
      ),
    ]);
    await tester.pumpWidget(const MaterialApp(home: GoalsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('GOALS'), findsOneWidget);
    expect(find.text('Launch V1 Beta'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('1/3 milestones'), findsOneWidget);
    expect(find.text('User testing'), findsOneWidget);
    // Toggle the second step: progress jumps to 67%.
    await tester.tap(find.text('Build prototype'));
    await tester.pump();
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('2/3 milestones'), findsOneWidget);
  });

  testWidgets('empty goals show the planter, not analytics',
      (tester) async {
    GoalStore.instance.debugFill();
    await tester.pumpWidget(const MaterialApp(home: GoalsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('No long-term goals yet'), findsOneWidget);
    expect(find.text('FOCUS THIS WEEK'), findsNothing);
    expect(find.text('STRONGEST TAGS'), findsNothing);
  });
}
