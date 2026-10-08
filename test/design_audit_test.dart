// TEMPORARY design audit — prints contrast ratios + measured tap targets
// and line lengths so the critique rests on numbers. Delete after review.
import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/theme/sakura_theme.dart';
import 'package:daily_bloom/widgets/contribution_heatmap.dart';
import 'package:daily_bloom/widgets/task_card.dart';
import 'package:daily_bloom/widgets/task_flow_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

double _lum(Color c) {
  final v = c.computeLuminance();
  return v;
}

double ratio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void _report(String label, Color fg, Color bg) {
  final r = ratio(fg, bg);
  final verdict = r >= 4.5
      ? 'AAA'
      : r >= 3.0
          ? 'AA-large only'
          : 'FAIL';
  // ignore: avoid_print
  print('  ${label.padRight(34)} ${r.toStringAsFixed(2).padLeft(6)}  $verdict');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('contrast audit — every theme', () {
    for (final t in [
      AppThemes.midnight,
      AppThemes.sakura,
      AppThemes.kyoto,
      AppThemes.ocean
    ]) {
      // ignore: avoid_print
      print('\n== ${t.name} (bg ${hex(t.background)}, card ${hex(t.surface)})');
      _report('ink on card (body/title)', t.ink, t.surface);
      _report('inkSoft on card (secondary)', t.inkSoft, t.surface);
      _report('inkFaint on card (labels)', t.inkFaint, t.surface);
      _report('primary on card (links)', t.primary, t.surface);
      _report('tagText on tagBg', t.tagText, t.tagBg);
      _report('heat0 vs surface (empty cell)', t.heat0, t.surface);
      _report('heat1 vs surface', t.heat1, t.surface);
      _report('heat2 vs surface', t.heat2, t.surface);
      _report('heatPeak vs heat4 (peak dot)', t.heatPeak, t.heat4);
      _report('cardBorder vs surface (edge)', t.cardBorder, t.surface);
      _report('navInactive on surface', t.navInactive, t.surface);
    }
  });

  testWidgets('measured geometry at real widths', (tester) async {
    for (final w in [390.0, 1280.0]) {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const task = Task(
        id: 'p1',
        title: 'Ship the onboarding redesign to the staging ring',
        tag: 'design',
        status: 'todo',
        description:
            'A deliberately long description so measure overflow behaviour too.',
        avatarLabel: 'OP',
        comments: 3,
        priority: 'high',
        recurring: 'none',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              const ContributionHeatmap(
                  days: [], bestStreakLabel: 'Best streak: 4 days'),
              const SizedBox(height: 12),
              const TaskCard(task: task),
              const SizedBox(height: 12),
              TaskFlowList(
                todo: const [task],
                progress: const [],
                done: const [],
                onTap: (_) {},
                onOpen: (_) {},
                onToggleSub: (_, __) {},
                onTimer: (_) {},
              ),
            ]),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // ignore: avoid_print
      print('\n== width $w');

      // Approximate characters-per-line for the long body text.
      final desc = find.descendant(
          of: find.byType(TaskCard),
          matching: find.text(task.description));
      if (desc.evaluate().isNotEmpty) {
        final r = tester.getRect(desc.first);
        final painter = TextPainter(
          text: TextSpan(
              text: task.description,
              style: const TextStyle(fontSize: 12)),
          textDirection: TextDirection.ltr,
          maxLines: 1)..layout();
        // ignore: avoid_print
        print('  desc box width ${r.width.toStringAsFixed(0)}px  '
            'chars if unconstrained: ${painter.width.toStringAsFixed(0)}px / '
            '${(painter.width / 6.4).toStringAsFixed(0)} chars');
      }

      // Smallest painted tap targets.
      final taps = <String, Rect>{};
      for (final e in find.byType(GestureDetector).evaluate()) {
        final w2 = e.widget as GestureDetector;
        if (w2.onTap == null) continue;
        final r = tester.getRect(find.byWidget(w2));
        if (r.width <= 0 || r.height <= 0) continue;
        taps['tap@${r.left.toStringAsFixed(0)},${r.top.toStringAsFixed(0)}'] = r;
      }
      final small = taps.values.where((r) => r.height < 44).toList()
        ..sort((a, b) => a.height.compareTo(b.height));
      // ignore: avoid_print
      print('  tap targets total=${taps.length}  under 44px tall=${small.length}');
      for (final r in small.take(6)) {
        // ignore: avoid_print
        print('    small: ${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)}');
      }

      // Heatmap cell size at this width.
      final heat = find.byType(ContributionHeatmap);
      final cellFinder = find.descendant(of: heat, matching: find.byType(Container));
      final heatRect = tester.getRect(heat);
      // ignore: avoid_print
      print('  heatmap card ${heatRect.width.toStringAsFixed(0)}px wide, '
          '${tester.getRect(cellFinder.first).width.toStringAsFixed(1)}px first inner box');
    }
  });
}

String hex(Color c) =>
    '#${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
        '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();