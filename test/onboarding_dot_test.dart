import 'package:daily_bloom/widgets/daily_bloom_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: DailyBloomAppBar())));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('first run shows the dot, opening clears it for good',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await _pump(tester);
    expect(tester.takeException(), isNull);
    // Dot = 6px primary circle next to the diamond.
    expect(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.constraints?.maxWidth == 6 &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
        findsOneWidget);
    // Opening the sheet clears the dot and persists.
    await tester.tap(find.byIcon(LucideIcons.diamond));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('WHAT COINS MEAN'), findsOneWidget);
    await tester.tapAt(const Offset(200, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Rebuild fresh (same prefs): dot stays gone.
    await _pump(tester);
    expect(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.constraints?.maxWidth == 6 &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}
