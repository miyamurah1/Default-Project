import 'package:daily_bloom/screens/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GoalsScreen renders header and sections offline',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GoalsScreen()),
    );
    await tester.pump();
    // Let the (failing, offline) API calls settle.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('GOALS'), findsOneWidget);
    // Full offline render: hero, 4 tiles, tags, week chart.
    expect(find.text('0 min focused'), findsOneWidget);
    expect(find.text('STRONGEST TAGS'), findsOneWidget);
    expect(find.text('FOCUS THIS WEEK'), findsOneWidget);
    expect(find.text('Offline — connect to load.'), findsNWidgets(3));
    expect(find.text('FOCUS MINS'), findsOneWidget);
    expect(find.text('DAY STREAK'), findsOneWidget);
  });

  testWidgets('GoalsScreen renders the wide dashboard on laptop widths',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const MaterialApp(home: GoalsScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('GOALS'), findsOneWidget);
    expect(find.text('0 min focused'), findsOneWidget);
    expect(find.text('FOCUS THIS WEEK'), findsOneWidget);
    expect(find.text('COMPLETION'), findsOneWidget);
    expect(find.text('PEAK DAY'), findsOneWidget);
    // New xwide contract: the week chart spans full width BELOW the
    // two columns (left of + below the tags card), instead of sitting
    // inside the right column and stranding a void under the tiles.
    final tagsLeft = tester.getTopLeft(find.text('STRONGEST TAGS'));
    final weekLeft = tester.getTopLeft(find.text('FOCUS THIS WEEK'));
    expect(weekLeft.dx, lessThan(tagsLeft.dx));
    expect(weekLeft.dy, greaterThan(tagsLeft.dy));
  });
}
