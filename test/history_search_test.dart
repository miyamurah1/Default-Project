import 'package:daily_bloom/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('History search filters and clears', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HistoryScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('HISTORY'), findsOneWidget);

    // Open search, type a query with no matches offline.
    await tester.tap(find.byTooltip('Search history'));
    await tester.pump();
    await tester.enterText(
        find.byType(TextField), 'zzz-no-match');
    await tester.pump();
    expect(find.textContaining('No completed tasks match'),
        findsOneWidget);
    expect(find.textContaining('No subtask ticks match'),
        findsOneWidget);

    // Closing search restores the default empty states.
    await tester.tap(find.byTooltip('Close search'));
    await tester.pump();
    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.textContaining('No completed tasks match'),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}
