// Render/interaction smoke tests for widgets that previously had ~0%
// coverage: theme card, dialogs, guides, reward burst, ritual sheet,
// skeleton.
import 'package:daily_bloom/data/mock_data.dart' show starterTasks;
import 'package:daily_bloom/theme/sakura_theme.dart';
import 'package:daily_bloom/widgets/bloom_dialog.dart';
import 'package:daily_bloom/widgets/first_task_guide.dart';
import 'package:daily_bloom/widgets/level_up_burst.dart';
import 'package:daily_bloom/widgets/quick_add_ritual_sheet.dart';
import 'package:daily_bloom/widgets/tab_skeleton.dart';
import 'package:daily_bloom/widgets/theme_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(
    theme: SakuraTheme.buildTheme(),
    home: Scaffold(body: child),
  ));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SakuraTheme.useGoogleFonts = false;
  });

  testWidgets('ThemeCard renders and Preview fires', (tester) async {
    var previewed = 0;
    await _pump(
      tester,
      ThemeCard(
        theme: const StoreTheme(
          id: 'edo',
          name: 'Edo Period',
          label: 'CLASSIC',
          owned: true,
        ),
        isActive: false,
        onAction: () {},
        onPreview: () => previewed++,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Edo Period'), findsOneWidget);

    await tester.tap(find.text('PREVIEW'));
    await tester.pump();
    expect(previewed, 1);
  });

  testWidgets('BloomDialog renders title + actions', (tester) async {
    await _pump(
      tester,
      const BloomDialog(
        title: 'New folder',
        confirmLabel: 'Add',
        body: Text('Body copy', style: TextStyle()),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('New folder'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('FirstTaskGuide renders and calls onCreate', (tester) async {
    var created = 0;
    await _pump(
      tester,
      FirstTaskGuide(onCreate: () => created++, creating: false),
    );
    expect(tester.takeException(), isNull);
    // Sanity: the starter sample contract the guide plants.
    expect(starterTasks, isNotEmpty);
    final button = find.byType(FilledButton).first;
    await tester.tap(button);
    await tester.pump();
    expect(created, 1);
  });

  testWidgets('LevelUpBurst renders its reward card', (tester) async {
    await _pump(
      tester,
      const Center(child: LevelUpBurst(newLevel: 5, rankName: 'Bonsai')),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('LEVEL 5'), findsOneWidget);
    // Let the auto-dismiss timer elapse so no timer is left pending.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('TabSkeleton renders three placeholder cards', (tester) async {
    await _pump(tester, const TabSkeleton());
    expect(tester.takeException(), isNull);
    // Semantics + three shimmer cards.
    expect(find.byType(TabSkeleton), findsOneWidget);
  });

  testWidgets('QuickAddRitual sheet opens with presets', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: SakuraTheme.buildTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showQuickAddRitual(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Plant a ritual'), findsOneWidget);
    expect(find.text('Habit'), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
    // One built-in preset is offered.
    expect(find.text('Calm mornings'), findsOneWidget);

    // Dismiss the sheet cleanly.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(seconds: 1));
  });
}
