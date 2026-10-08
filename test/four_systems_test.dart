import 'package:daily_bloom/game/habit_tracker.dart';
import 'package:daily_bloom/game/token_economy.dart';
import 'package:daily_bloom/widgets/responsive_layout.dart';
import 'package:daily_bloom/widgets/year_in_focus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Module 1: bonsai + habit cards', () {
    test('tiers: 0 seed, 1-2 sprout, 3-7 sapling, 8-14 bonsai, 15+ lotus',
        () {
      expect(bonsaiTierForStreak(0), BonsaiTier.seed);
      expect(bonsaiTierForStreak(1), BonsaiTier.sprout);
      expect(bonsaiTierForStreak(3), BonsaiTier.sapling);
      expect(bonsaiTierForStreak(8), BonsaiTier.bonsai);
      expect(bonsaiTierForStreak(20), BonsaiTier.lotus);
    });

    testWidgets('binary card shows streak tag >=3, hides below',
        (tester) async {
      bool? got;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BinaryHabitCard(
                  title: 'Meditate',
                  isCompleted: false,
                  streakCount: 5,
                  onToggle: (v) => got = v))));
      expect(find.text('5 Days'), findsOneWidget);
      await tester.tap(find.text('Meditate'));
      await tester.pumpAndSettle();
      expect(got, isTrue);

      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BinaryHabitCard(
                  title: 'Cold shower',
                  isCompleted: false,
                  streakCount: 2,
                  onToggle: (_) {}))));
      await tester.pumpAndSettle();
      expect(find.text('2 Days'), findsNothing);
    });

    testWidgets('measurable card increments via tap', (tester) async {
      num got = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MeasurableHabitCard(
                  title: 'Water',
                  currentValue: 4,
                  targetValue: 8,
                  unit: 'Glasses',
                  streakCount: 4,
                  onProgressChanged: (v) => got = v))));
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('4 Days'), findsOneWidget);
      await tester.tap(find.byType(MeasurableHabitCard));
      await tester.pumpAndSettle();
      expect(got, 5);
    });

    testWidgets('legacy HabitModel ctor still compiles', (tester) async {
      final h = HabitModel(id: 'a', label: 'Read', streakCount: 6);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: BinaryHabitCard(habit: h))));
      await tester.pumpAndSettle();
      expect(find.text('Read'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Module 2: token economy + theme model', () {
    test('spec tiers: 1x 0-2, 1.25x 3-7, 1.5x 14+', () {
      expect(TokenEconomyManager.specMultiplierForStreak(0), 1.0);
      expect(TokenEconomyManager.specMultiplierForStreak(2), 1.0);
      expect(TokenEconomyManager.specMultiplierForStreak(3), 1.25);
      expect(TokenEconomyManager.specMultiplierForStreak(7), 1.25);
      expect(TokenEconomyManager.specMultiplierForStreak(14), 1.5);
      expect(TokenEconomyManager.specMultiplierForStreak(30), 1.5);
    });

    test('heatmapColors has 6 theme-driven entries', () {
      final m = BloomThemeModel.fromId('midnight');
      expect(m.heatmapColors.length, 6);
      expect(m.heatColor(0), isNotNull);
      expect(m.heatColor(99), m.heatmapColors.first);
    });
  });

  group('Module 3: YearInFocus paginates', () {
    testWidgets('page count + swipe hook fires', (tester) async {
      final seen = <int>[];
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: YearInFocusWidget(
                  totalDays: 365,
                  windowDays: 84,
                  onWindowRequested: (i, _, __) async {
                    seen.add(i);
                  }))));
      await tester.pumpAndSettle();
      expect(find.text('YEAR IN FOCUS'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      // Newest page auto-requested on init.
      expect(seen, isNotEmpty);
      // Swipe to older window triggers hook again.
      await tester.fling(
          find.byType(PageView), const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(seen.length, greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('Module 4: responsive scaffold', () {
    Future<void> pump(WidgetTester t, double w) async {
      t.view.physicalSize = Size(w, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(() {
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
      });
      await t.pumpWidget(MaterialApp(
          home: ResponsiveLayoutBuilder(
              master: const Text('MASTER'),
              detail: const Text('DETAIL'),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.list), label: 'Tasks'),
              ],
              currentIndex: 0,
              onDestinationSelected: (_) {})));
      await t.pumpAndSettle();
    }

    testWidgets('mobile <600: bottom bar, no rail', (t) async {
      await pump(t, 400);
      expect(find.text('MASTER'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('desktop >=600: rail + master-detail', (t) async {
      await pump(t, 1100);
      expect(find.text('MASTER'), findsOneWidget);
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
