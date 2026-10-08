// FlowStateJuiceWidget: combo glow + drifting gain labels + tap bounce.
// The ambient glow loops forever, so bounded pumps only.
import 'package:daily_bloom/game/flow_state_juice.dart';
import 'package:daily_bloom/theme/sakura_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    theme: SakuraTheme.buildTheme(),
    home: Scaffold(body: child),
  ));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SakuraTheme.useGoogleFonts = false;
  });

  testWidgets('renders at combo 0 and forwards taps', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      FlowStateJuiceWidget(
        comboLevel: 0,
        onTap: () => taps++,
        child: const SizedBox(width: 120, height: 40),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(FlowStateJuiceWidget));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('shows a glow from combo 1', (tester) async {
    await _pump(
      tester,
      const FlowStateJuiceWidget(
        comboLevel: 1,
        child: SizedBox(width: 120, height: 40),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(Opacity), findsWidgets);
  });

  testWidgets('spawns a drifting gain label when the combo reaches 3+',
      (tester) async {
    Widget build(int combo) => FlowStateJuiceWidget(
          comboLevel: combo,
          gainLabel: (c) => '+9 XP · x$c',
          child: const SizedBox(width: 120, height: 40),
        );

    await _pump(tester, build(2));
    // Rebuild with a higher combo -> floater spawns in didUpdateWidget.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: build(3)),
    ));
    await tester.pump();
    expect(find.text('+9 XP · x3'), findsOneWidget);

    // Let the floater finish (1.2s) and de-register.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump();
    expect(find.text('+9 XP · x3'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
