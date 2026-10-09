import 'package:daily_bloom/widgets/bloom_snackbar.dart';
import 'package:daily_bloom/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showBloomSnackBar replaces instead of queuing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {},
              child: const Text('tap'),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.text('tap'));
    showBloomSnackBar(context, 'first');
    await tester.pump();
    showBloomSnackBar(context, 'second');
    await tester.pump();
    // Only the latest toast is visible — no stale queue behind it.
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('Entrance onceKey plays once per session', (tester) async {
    Entrance.debugResetOnceKeys();
    Widget sheet(String label) => MaterialApp(
          home: Entrance(
            onceKey: 'smooth-test-row',
            delayMs: 300,
            child: Text(label),
          ),
        );

    // First mount: hidden until the cascade timer fires.
    await tester.pumpWidget(sheet('hi'));
    await tester.pump();
    final hidden = find.byWidgetPredicate(
        (w) => w is Opacity && w.opacity == 0);
    expect(hidden, findsOneWidget);

    // Let the cascade play out — only now is the key marked as played.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(hidden, findsNothing);

    // Second mount with the same key: instant, no replay. Pump an
    // unrelated frame first so the Entrance state truly remounts.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpWidget(sheet('hi'));
    await tester.pump();
    expect(hidden, findsNothing);
    expect(find.text('hi'), findsOneWidget);
    Entrance.debugResetOnceKeys();
  });
}
