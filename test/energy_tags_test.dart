import 'package:daily_bloom/data/energy_store.dart';
import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/screens/task_detail_screen.dart';
import 'package:daily_bloom/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    EnergyStore.instance.debugFill();
  });

  test('valid levels only', () {
    expect(EnergyStore.valid('low'), isTrue);
    expect(EnergyStore.valid('medium'), isTrue);
    expect(EnergyStore.valid('high'), isTrue);
    expect(EnergyStore.valid('extreme'), isFalse);
    expect(EnergyStore.valid(null), isFalse);
    expect(EnergyStore.valid(''), isFalse);
  });

  test('set/get/clear round-trips through prefs', () async {
    final store = EnergyStore.instance;
    await store.load();
    expect(store.levelFor('t1'), isNull);
    await store.setLevel('t1', EnergyStore.high);
    expect(store.levelFor('t1'), 'high');
    // Invalid writes are ignored, never stored.
    await store.setLevel('t2', 'extreme');
    expect(store.levelFor('t2'), isNull);
    await store.setLevel('t1', null);
    expect(store.levelFor('t1'), isNull);
    // Reload reads back what persist wrote.
    await store.setLevel('t9', EnergyStore.low);
    await EnergyStore.instance.load();
    expect(EnergyStore.instance.levelFor('t9'), 'low');
  });

  test('prune drops only orphaned ids', () async {
    final store = EnergyStore.instance;
    await store.load();
    await store.setLevel('live', EnergyStore.medium);
    await store.setLevel('gone', EnergyStore.high);
    await store.prune(['live', 'other']);
    expect(store.levelFor('live'), 'medium');
    expect(store.levelFor('gone'), isNull);
  });

  testWidgets('card shows the energy pill', (tester) async {
    EnergyStore.instance.debugFill({'t1': EnergyStore.medium});
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: TaskCard(
                task: Task(id: 't1', title: 'T', tag: 'General')))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('MEDIUM'), findsOneWidget);
    expect(find.byIcon(LucideIcons.batteryMedium), findsOneWidget);
  });

  testWidgets('card hides the pill when unset', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: TaskCard(
                task: Task(id: 't2', title: 'T', tag: 'General')))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('MEDIUM'), findsNothing);
    expect(find.text('LOW'), findsNothing);
    expect(find.text('HIGH'), findsNothing);
  });

  testWidgets('detail segments set and clear offline', (tester) async {
    const task = Task(id: 't3', title: 'T', tag: 'General');
    await tester.pumpWidget(
        const MaterialApp(home: TaskDetailScreen(task: task)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('ENERGY'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('High'));
    await tester.pump();
    expect(EnergyStore.instance.levelFor('t3'), 'high');
    // Tapping the selected level clears back to unset.
    await tester.tap(find.text('High'));
    await tester.pump();
    expect(EnergyStore.instance.levelFor('t3'), isNull);
    expect(tester.takeException(), isNull);
  });
}
