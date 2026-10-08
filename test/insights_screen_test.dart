import 'package:daily_bloom/screens/insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('insights offline is honest and silent', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await tester.pumpWidget(const MaterialApp(home: InsightsScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Could not load insights.'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
