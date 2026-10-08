// TEMPORARY diagnostic probe — prints Home geometry at several widths
// so wasted space can be measured numerically. Delete after measuring.
import 'package:daily_bloom/screens/home_screen.dart';
import 'package:daily_bloom/widgets/contribution_heatmap.dart';
import 'package:daily_bloom/widgets/daily_intention_card.dart';
import 'package:daily_bloom/widgets/task_flow_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final w in [360.0, 700.0, 1100.0, 1400.0, 1920.0]) {
    testWidgets('probe ${w.toInt()}', (tester) async {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      debugPrint('=== width $w exception=${tester.takeException()}');

      final hud = find.byKey(const ValueKey('home_hud_card'));
      if (hud.evaluate().isNotEmpty) {
        final r = tester.getRect(hud);
        debugPrint('hud rect=$r  rightGap=${w - r.right}');
      } else {
        debugPrint('hud not found');
      }

      final heat = find.byType(ContributionHeatmap);
      if (heat.evaluate().isNotEmpty) {
        final r = tester.getRect(heat);
        // Widest painted child of the heatmap = the month-label row.
        final grid = tester.getRect(
            find.descendant(of: heat, matching: find.byType(Row)).last);
        debugPrint('heatmap card=$r gridRow=$grid');
      } else {
        debugPrint('heatmap not found (off-screen?)');
      }

      final flow = find.byType(TaskFlowList);
      if (flow.evaluate().isNotEmpty) {
        debugPrint('flow=${tester.getRect(flow)}');
      }
      final intention = find.byType(DailyIntentionCard);
      if (intention.evaluate().isNotEmpty) {
        debugPrint('intention=${tester.getRect(intention)}');
      }
    });
  }
}