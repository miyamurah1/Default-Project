import 'package:daily_bloom/screens/home_screen.dart';
import 'package:daily_bloom/widgets/contribution_heatmap.dart';
import 'package:daily_bloom/widgets/task_flow_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home's product contract (Zen Bento era):
/// bento header (~130px) -> heat map -> shortcuts -> Today's Flow board.
/// The board is intentionally LAST — the day's evidence and doors sit
/// above the work.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        // First-run concept map dismissed: the steady-state layout.
        'bloom_concept_seen_v1': true,
      }));

  testWidgets('heat map + shortcuts sit above the board (board last)',
      (tester) async {
    for (final mobile in [true, false]) {
      final w = mobile ? 390.0 : 1400.0;
      tester.view.physicalSize = Size(w, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'width $w');

      final header = find.byKey(const ValueKey('home_hud_card'));
      final board = find.byType(TaskFlowList, skipOffstage: false);
      final heat = find.byType(ContributionHeatmap);
      final shortcuts = mobile
          ? find.byKey(const ValueKey('home_quick_link_0'))
          : find.byKey(const ValueKey('home_quick_links'));

      expect(header, findsOneWidget, reason: 'width $w');
      expect(board, findsOneWidget, reason: 'width $w');
      expect(heat, findsOneWidget, reason: 'width $w');
      expect(shortcuts, findsOneWidget, reason: 'width $w');

      final headerRect = tester.getRect(header);
      final heatRect = tester.getRect(heat);
      final shortcutRect = tester.getRect(shortcuts);
      final boardRect = tester.getRect(board);

      // Compact bento: ~130px tall (allow a small tolerance).
      expect(headerRect.height, lessThanOrEqualTo(150),
          reason: 'bento stays compact, width $w');
      expect(headerRect.height, greaterThanOrEqualTo(110),
          reason: 'bento is a real header, width $w');
      // Order: header -> heat map -> shortcuts -> board (board last).
      expect(headerRect.bottom, lessThanOrEqualTo(heatRect.top),
          reason: 'heat map after header, width $w');
      expect(heatRect.bottom, lessThanOrEqualTo(shortcutRect.top),
          reason: 'shortcuts under the heat map, width $w');
      expect(shortcutRect.bottom, lessThanOrEqualTo(boardRect.top),
          reason: 'board last, width $w');
    }
  });

  testWidgets('bento header carries the intention, seedling and streak',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    // Intention voice + seedling streak are both in the compact header;
    // no legacy habit/milestone UI lives on Home.
    expect(find.text("Today's focus"), findsOneWidget);
    expect(find.textContaining('d · x'), findsOneWidget);
    expect(find.text('SEASONAL JOURNEY'), findsNothing);
  });

  testWidgets('bento header spans the full content width', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    final hudTopLeft =
        tester.getTopLeft(find.byKey(const ValueKey('home_hud_card')));
    final hud = tester.getSize(find.byKey(const ValueKey('home_hud_card')));
    expect(hudTopLeft.dx, 20);
    expect(hudTopLeft.dx + hud.width, 1400 - 20);
  });
}
