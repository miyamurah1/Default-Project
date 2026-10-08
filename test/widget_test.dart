// Daily Bloom widget tests — auth-gated entry point.
//
// The app boots to AuthGate: splash -> LoginScreen (logged out) or
// AppShell (logged in). SharedPreferences is mocked so restore()
// completes without platform channels. Firebase has no native app in
// tests, so AuthGate degrades to the logged-out stream (see _authState).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_bloom/main.dart';

void main() {

  testWidgets('Boot shows login when no session is stored', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DailyBloomApp());
    // Splash first (restore is async), then login. Avoid pumpAndSettle:
    // the splash spinner never "settles".
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('WELCOME BACK'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets('Signup link is visible on login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DailyBloomApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Create an account'), findsOneWidget);
  });
}
