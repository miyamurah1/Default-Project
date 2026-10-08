import 'package:daily_bloom/screens/folder_detail_screen.dart';
import 'package:daily_bloom/data/api_client.dart';
import 'package:daily_bloom/widgets/daily_bloom_app_bar.dart';
import 'package:daily_bloom/widgets/sakura_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Code-level accessibility pass (TalkBack/VoiceOver behavior itself
// needs a real device): every icon-only control must declare a role +
// label. Asserted at the widget layer — no semantics handles needed.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('bottom nav tabs declare labelled buttons', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: SakuraBottomNav(
                currentIndex: 0, onTap: (_) {}))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final label in SakuraBottomNav.labels) {
      expect(
          find.byWidgetPredicate((w) =>
              w is Semantics &&
              (w.properties.button ?? false) &&
              w.properties.label == label),
          findsOneWidget,
          reason: '$label is a labelled button');
    }
    // Icons stay decorative (no double announcement).
    expect(find.byType(ExcludeSemantics), findsWidgets);
  });

  testWidgets('token pill announces its purpose', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(appBar: DailyBloomAppBar())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            (w.properties.button ?? false) &&
            (w.properties.label ?? '').contains('tokens')),
        findsOneWidget);
  });

  testWidgets('back chevrons carry tooltips', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: FolderDetailScreen(
            folder: BloomFolder(name: 'Productivity'))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(
        find.byWidgetPredicate(
            (w) => w is Tooltip && w.message == 'Back'),
        findsOneWidget);
  });
}
