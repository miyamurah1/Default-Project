import 'package:daily_bloom/data/habit_store.dart';
import 'package:daily_bloom/game/gamification_state.dart';
import 'package:daily_bloom/screens/app_shell.dart';
import 'package:daily_bloom/screens/habits_screen.dart';
import 'package:daily_bloom/widgets/sakura_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('streak counts consecutive done-days ending today or yesterday', () {
    final now = DateTime(2026, 9, 30);
    String day(int ago) => HabitStore.dayKey(now.subtract(Duration(days: ago)));
    expect(HabitStore.streakOf({day(0): 1, day(1): 1, day(2): 1}, false, 1, now), 3);
    expect(HabitStore.streakOf({day(1): 1, day(2): 1}, false, 1, now), 2);
    expect(HabitStore.streakOf({day(0): 1, day(2): 1}, false, 1, now), 1);
    expect(HabitStore.streakOf({day(0): 5, day(1): 8, day(2): 8}, true, 8, now), 2);
  });

  group('streak freeze', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GamificationStateNotifier.instance.debugReset();
    });
    tearDown(() {
      HabitStore.instance.debugFill();
      GamificationStateNotifier.instance.debugReset();
    });

    Map<String, num> threeRun() {
      final now = DateTime.now();
      String day(int ago) => HabitStore.dayKey(now.subtract(Duration(days: ago)));
      return {day(0): 1, day(1): 1, day(2): 1};
    }

    test('freeze stamps the live streak as the shield', () async {
      final store = HabitStore.instance;
      store.debugFill(habits: [Habit(id: 'h1', name: 'Read', log: threeRun())]);
      expect(store.habitById('h1')!.streak, 3);
      expect(await store.freezeHabit('h1'), isTrue);
      final frozen = store.habitById('h1')!;
      expect(frozen.frozen, isTrue);
      expect(frozen.frozenStreak, 3);
      // Second freeze is a no-op.
      expect(await store.freezeHabit('h1'), isFalse);
      expect(await store.freezeHabit('nope'), isFalse);
    });

    test('frozen streak survives an emptied log', () {
      HabitStore.instance.debugFill(habits: const [
        Habit(id: 'h1', name: 'Read', frozen: true, frozenStreak: 3),
      ]);
      // Without the shield this would compute to 0.
      expect(HabitStore.instance.habitById('h1')!.streak, 3);
    });

    test('thaw costs 500 and recomputes honestly', () async {
      final store = HabitStore.instance;
      final game = GamificationStateNotifier.instance;
      store.debugFill(habits: const [
        Habit(id: 'h1', name: 'Read', frozen: true, frozenStreak: 3),
      ]);
      // Broke: no balance, no state touched.
      expect(await store.unfreezeHabit('h1'), isFalse);
      expect(store.habitById('h1')!.frozen, isTrue);
      expect(game.tokens, 0);
      game.addTokens(600);
      expect(await store.unfreezeHabit('h1'), isTrue);
      final thawed = store.habitById('h1')!;
      expect(thawed.frozen, isFalse);
      expect(game.tokens, 100);
      // Shield gone: empty log recomputes to an honest 0.
      expect(thawed.streak, 0);
      expect(await store.unfreezeHabit('h1'), isFalse);
    });

    test('freeze fields survive a persistence round-trip', () {
      const h = Habit(id: 'h1', name: 'Read', frozen: true, frozenStreak: 5);
      final back = Habit.fromJson(h.toJson());
      expect(back.frozen, isTrue);
      expect(back.frozenStreak, 5);
      final plain = Habit.fromJson(const Habit(id: 'h2', name: 'Walk').toJson());
      expect(plain.frozen, isFalse);
      expect(plain.frozenStreak, 0);
    });
  });
  testWidgets('Habits page shows progress, journey, goals and habit cards', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => HabitStore.instance.debugFill());
    await tester.pumpWidget(const MaterialApp(home: HabitsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Contract (trust): fresh prefs load honestly empty — no seeded demo
    // goals or streaks. The guided empty state teaches the shape instead.
    expect(find.text('Begin with one small promise'), findsOneWidget);
    expect(find.text('Morning meditation'), findsNothing);
    // Pinned content renders once provided (debugFill after load settles,
    // so initState's load cannot overwrite it).
    HabitStore.instance.debugFill(
      goals: const [HabitGoal(id: 'g1', name: 'Calm mornings', intention: 'Start steady.')],
      habits: [Habit(id: 'h1', name: 'Morning meditation', goalId: 'g1', log: {HabitStore.dayKey(DateTime.now()): 1})],
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Habits'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('THE JOURNEY'), findsOneWidget);
    expect(find.text('Sprout'), findsOneWidget);
    expect(find.text('Calm mornings'), findsOneWidget);
    expect(find.text('Morning meditation'), findsOneWidget);
  });
  testWidgets('frozen habit shows the snowflake pill', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => HabitStore.instance.debugFill());
    await tester.pumpWidget(const MaterialApp(home: HabitsScreen()));
    await tester.pumpAndSettle();
    HabitStore.instance.debugFill(habits: const [
      Habit(id: 'h1', name: 'Read', frozen: true, frozenStreak: 4),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Read'), findsOneWidget);
    expect(find.byIcon(LucideIcons.snowflake), findsOneWidget);
  });
  testWidgets('empty shelf plants a ritual on tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() {
      HabitStore.instance.debugFill();
      SharedPreferences.setMockInitialValues({});
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(const MaterialApp(home: HabitsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('OR START FROM A RITUAL'), findsOneWidget);
    await tester.tap(find.text('Calm mornings'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Empty state (and its shelf) gives way to the planted goal.
    expect(find.text('OR START FROM A RITUAL'), findsNothing);
    expect(find.text('Morning meditation'), findsOneWidget);
  });
  testWidgets('tapping a goal name opens rename', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => HabitStore.instance.debugFill());
    await tester.pumpWidget(const MaterialApp(home: HabitsScreen()));
    await tester.pumpAndSettle();
    HabitStore.instance.debugFill(
      goals: const [HabitGoal(id: 'g1', name: 'Calm mornings')],
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Calm mornings'));
    await tester.pumpAndSettle();
    expect(find.text('Edit goal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('AppShell stacks the same 4-tab bar on every width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    expect(SakuraBottomNav.items.length, 4);
    expect(SakuraBottomNav.labels[2], 'Folders');
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SakuraBottomNav), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('ritual presets', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => HabitStore.instance.debugFill());

    RitualPreset calm() => RitualPresets.presets
        .firstWhere((p) => p.id == 'calm-mornings');

    test('plants goal plus habits, counts additions', () async {
      final store = HabitStore.instance;
      store.debugFill();
      expect(await store.applyPreset(calm()), 3);
      expect(store.goals.map((g) => g.name), contains('Calm mornings'));
      final names = store.habits.map((h) => h.name).toSet();
      expect(names,
          containsAll(['Morning meditation', 'Drink water']));
      expect(store.habitsFor(store.goals.single.id).length, 2);
    });

    test('second apply plants nothing', () async {
      final store = HabitStore.instance;
      store.debugFill();
      expect(await store.applyPreset(calm()), 3);
      expect(await store.applyPreset(calm()), 0);
      expect(store.goals.length, 1);
      expect(store.habits.length, 2);
    });

    test('partial shelf fills only the gaps', () async {
      final store = HabitStore.instance;
      store.debugFill();
      final g = await store.addGoal(name: 'calm MORNINGS ');
      await store.addHabit(name: 'Morning meditation', goalId: g.id);
      expect(await store.applyPreset(calm()), 1);
      expect(store.habits.map((h) => h.name).toSet(),
          containsAll(['Morning meditation', 'Drink water']));
    });
  });
}
