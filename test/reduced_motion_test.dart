// Reduced-motion parity: decorative animation is skipped, feedback kept.
import 'package:daily_bloom/widgets/petal_burst.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('PetalBurst keeps the tap but skips the flourish when reduced',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: Center(
            child: PetalBurst(
              onTap: () => taps++,
              child: const SizedBox(width: 24, height: 24),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // Baseline painters (Material internals included).
    final before = find.byType(CustomPaint).evaluate().length;
    await tester.tap(find.byType(PetalBurst));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(taps, 1, reason: 'tap still fires');
    expect(tester.takeException(), isNull);
    // No new petal painter mounted under reduced motion.
    expect(find.byType(CustomPaint).evaluate().length, before);
  });

  testWidgets('PetalBurst animates when motion is allowed', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PetalBurst(
            onTap: () {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      ),
    ));
    await tester.pump();

    final before = find.byType(CustomPaint).evaluate().length;
    await tester.tap(find.byType(PetalBurst));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CustomPaint).evaluate().length, greaterThan(before),
        reason: 'petals paint mid-flourish');

    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
