import 'package:daily_bloom/game/game.dart';
import 'package:daily_bloom/screens/home_screen.dart';
import 'package:daily_bloom/widgets/contribution_heatmap.dart';
import 'package:daily_bloom/widgets/daily_intention_card.dart';
import 'package:daily_bloom/widgets/task_flow_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home's product contract:
/// bento header -> planner -> visible 12-week evidence -> shortcuts ->
/// Today's Flow board FINAL. The board closes the page after the proof
/// and the doors; the heatmap reads on the page, collapsible on demand.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        // First-run concept map dismissed: the steady-state layout.
        'bloom_concept_seen_v1': true,
      }));

  testWidgets('board closes the page below evidence and doors',
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
      final heat = find.byType(ContributionHeatmap, skipOffstage: false);
      final disclosure = find.text('12-WEEK EVIDENCE');
      final shortcuts = mobile
          ? find.byKey(const ValueKey('home_quick_link_0'))
          : find.byKey(const ValueKey('home_quick_links'));

      expect(header, findsOneWidget, reason: 'width $w');
      expect(board, findsOneWidget, reason: 'width $w');
      expect(heat, findsOneWidget, reason: 'width $w');
      expect(disclosure, findsOneWidget, reason: 'width $w');
      expect(shortcuts, findsOneWidget, reason: 'width $w');

      final headerRect = tester.getRect(header);
      final boardRect = tester.getRect(board);
      final disclosureRect = tester.getRect(disclosure);
      final shortcutRect = tester.getRect(shortcuts);

      if (mobile) {
        // Narrow phones stack focus OVER level (full-width cells so
        // nothing ellipsises): taller than the desktop 130px band.
        expect(headerRect.height, greaterThanOrEqualTo(200),
            reason: 'stacked bento fits both cards, width $w');
        expect(headerRect.height, lessThanOrEqualTo(340),
            reason: 'stacked bento stays compact, width $w');
        // Focus card sits above the seedling/XP card.
        final focusTop =
            tester.getTopLeft(find.text("Today's focus")).dy;
        final xp = find.textContaining('/100 XP');
        // XP counter may vary with game state; fall back to streak line.
        final below = xp.evaluate().isNotEmpty
            ? tester.getTopLeft(xp).dy
            : tester.getTopLeft(find.textContaining('d · x')).dy;
        expect(focusTop, lessThan(below),
            reason: 'focus above level-up, width $w');
      } else {
        // Compact desktop bento: ~130px tall (allow a small tolerance).
        expect(headerRect.height, lessThanOrEqualTo(150),
            reason: 'bento stays compact, width $w');
        expect(headerRect.height, greaterThanOrEqualTo(110),
            reason: 'bento is a real header, width $w');
      }
      // Order: header -> evidence disclosure -> shortcuts -> board.
      // The board closes the page; the heatmap reads above the work.
      expect(headerRect.bottom, lessThanOrEqualTo(disclosureRect.top),
          reason: 'evidence after header, width $w');
      expect(disclosureRect.bottom,
          lessThanOrEqualTo(shortcutRect.top),
          reason: 'shortcuts under the evidence, width $w');
      expect(shortcutRect.bottom, lessThanOrEqualTo(boardRect.top),
          reason: 'board final, width $w');
    }
  });

  testWidgets('evidence reads by default, collapses on tap',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    // Visible by default: the grid reads on the page.
    expect(find.byType(ContributionHeatmap), findsOneWidget);
    expect(find.text('Hide'), findsOneWidget);

    await tester.tap(find.text('Hide'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(ContributionHeatmap), findsNothing,
        reason: 'heatmap collapses on demand');
    expect(find.text('Show'), findsOneWidget);
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

  testWidgets('phone bento fills its cell (bar bottoms out, rank fits)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);

    // The compact intention cell fills the 130px slot: the progress bar
    // pins to the bottom instead of leaving a dead band below it.
    final card = find.byType(DailyIntentionCard);
    final bar = find.descendant(
        of: card, matching: find.byType(LinearProgressIndicator));
    final cardRect = tester.getRect(card);
    final barRect = tester.getRect(bar);
    expect(cardRect.bottom - barRect.bottom, lessThanOrEqualTo(20),
        reason: 'progress bar hugs the card bottom');
    expect(
        barRect.top,
        greaterThan(
            tester.getTopLeft(find.text("Today's focus")).dy),
        reason: 'bar stays under the headline');

    // The rank line is never ellipsised: its paragraph measures as wide
    // as the unwrapped text (FittedBox shrinks it instead of clipping).
    final rank = GamificationStateNotifier.instance.rankName;
    final para = tester.renderObject<RenderParagraph>(find.text(rank));
    final natural = (TextPainter(
      text: TextSpan(style: para.text.style, text: rank),
      textDirection: TextDirection.ltr,
    )..layout())
        .width;
    expect(para.size.width, greaterThanOrEqualTo(natural - 1),
        reason: 'rank line must not be clipped at 360px');
  });
}
