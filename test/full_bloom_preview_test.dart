import 'package:daily_bloom/game/game.dart';
import 'package:daily_bloom/screens/full_bloom_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Lv100 Sakura badge lays out without overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BloomRankBadge(level: 100))),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FullBloomPreview demo renders without overflow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FullBloomPreview()),
    );
    await tester.pump();
    // Lotus unfold (900ms) + counter roll (1.5s) finish.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 1600));
    expect(tester.takeException(), isNull);

    // Replay path restarts both animations cleanly.
    await tester.ensureVisible(
      find.text('Replay unfolding lotus'),
    );
    await tester.pump();
    await tester.tap(find.text('Replay unfolding lotus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 1600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Season track fits 360px phones with last node visible',
      (tester) async {
    const milestones = [
      SeasonMilestone(title: 'First light', reward: '+50 XP'),
      SeasonMilestone(title: 'Seven dawns', reward: '◆ 50'),
      SeasonMilestone(title: 'Still water', reward: '+150 XP'),
      SeasonMilestone(title: 'Deep roots', reward: '◆ 150'),
      SeasonMilestone(title: 'Full bloom', reward: 'Sakura'),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SeasonalJourneyTrack(
                milestones: milestones,
                completedCount: 5,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // The last stone must sit inside the track — no clipping, no scroll.
    final track = tester.getRect(find.byType(SeasonalJourneyTrack));
    final last = tester.getRect(find.text('Full bloom'));
    expect(last.right, lessThanOrEqualTo(track.right + 0.5));
    expect(last.left, greaterThanOrEqualTo(track.left - 0.5));
    expect(find.text('Deep roots'), findsOneWidget);
  });

  testWidgets('Season track hugs center on wide screens, no dead gaps',
      (tester) async {
    const milestones = [
      SeasonMilestone(title: 'First light', reward: '+50 XP'),
      SeasonMilestone(title: 'Seven dawns', reward: '◆ 50'),
      SeasonMilestone(title: 'Still water', reward: '+150 XP'),
      SeasonMilestone(title: 'Deep roots', reward: '◆ 150'),
      SeasonMilestone(title: 'Full bloom', reward: 'Sakura'),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 800,
              child: SeasonalJourneyTrack(
                milestones: milestones,
                completedCount: 5,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // 5×76 + 4×44 = 556 content: grouped in the middle, not stretched.
    final first = tester.getRect(find.text('First light'));
    final last = tester.getRect(find.text('Full bloom'));
    expect(first.left, greaterThan(60));
    expect(last.right, lessThan(800 - 60));
  });
}
