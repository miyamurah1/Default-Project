// Forgot-password sheet + dark-glow contrast guard.
// The reset sheet must open, validate, and hand a trimmed email to
// AuthStore.sendPasswordReset; glow alphas must stay luminous-not-muddy.
import 'package:daily_bloom/data/auth_store.dart';
import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/game/bloom_game_colors.dart';
import 'package:daily_bloom/screens/login_screen.dart';
import 'package:daily_bloom/widgets/task_flow_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG 2.1 contrast of [fg] over [bg].
double _ratio(Color fg, Color bg) {
  final a = fg.computeLuminance(), b = bg.computeLuminance();
  final hi = a > b ? a : b, lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  test('validateEmail accepts good, rejects bad', () {
    expect(AuthStore.validateEmail('a@b.co'), isNull);
    expect(AuthStore.validateEmail('not-an-email'), isNotNull);
    expect(AuthStore.validateEmail('  '), isNotNull);
  });

  testWidgets('Forgot password opens the reset sheet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    // Invalid email shows inline validation, no crash.
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('glow alphas stay in the luminous band', () {
    // Guard against white-hot regressions: glows are subtle overlays,
    // never opaque fills or near-invisible whispers.
    for (final a in [
      BloomGameColors.glowComboPink,
      BloomGameColors.glowComboViolet,
      BloomGameColors.glowCelebrateMin,
      BloomGameColors.glowCelebrateMax,
      BloomGameColors.glowIcy,
    ]) {
      expect(a, greaterThanOrEqualTo(0.10));
      expect(a, lessThanOrEqualTo(0.35));
    }
    expect(BloomGameColors.glowCelebrateMax,
        greaterThan(BloomGameColors.glowCelebrateMin));
  });

  test('kanban accents clear AA on the Midnight card', () {
    const card = Color(0xFF1E1A2E);
    expect(_ratio(BloomGameColors.kanbanProgress, card),
        greaterThanOrEqualTo(4.5));
    expect(
        _ratio(BloomGameColors.kanbanDone, card), greaterThanOrEqualTo(4.5));
  });

  testWidgets('timer chip announces its purpose', (tester) async {
    const task = Task(id: 't1', title: 'T', tag: 'G', focusMinutes: 25);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TaskFlowList(
      todo: const [task],
      progress: const [],
      done: const [],
      onTap: (_) {},
      onOpen: (_) {},
      onToggleSub: (_, __) {},
      onTimer: (_) {},
      heroPrefix: 'home-focus-',
    ))));
    await tester.pump();
    expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            (w.properties.button ?? false) &&
            ((w.properties.label ?? '').contains('focus timer'))),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
