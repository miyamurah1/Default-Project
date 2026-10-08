import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_store.dart';
import '../theme/sakura_theme.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// Route guard — the only place that decides login vs app.
///
/// - Listens to [FirebaseAuth.authStateChanges] (the Firebase stream) AND
///   [AuthStore] (for the DB user profile). Both must be present to show the app.
/// - While the stored session is being verified, shows a calm sakura splash.
/// - Logout can never be bypassed with the back button (no named routes to pop).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// null until the first-launch flag has been read. While null and the
  /// user is logged in we keep showing the splash — never a flash of the
  /// app before onboarding.
  bool? _onboardingSeen;

  @override
  void initState() {
    super.initState();
    AuthStore.instance.restore();
    _loadOnboarding();
  }

  Future<void> _loadOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _onboardingSeen =
            prefs.getBool(OnboardingScreen.seenKey) ?? false;
      });
    } catch (_) {
      // Prefs unavailable (unlikely): don't trap the user in onboarding.
      if (mounted) setState(() => _onboardingSeen = true);
    }
  }

  /// Firebase's own stream is the ground truth for identity.
  /// Falls back to logged-out when Firebase isn't initialised — that only
  /// happens in widget tests (production always runs Firebase.initializeApp
  /// in main() first), so this never masks a real failure.
  static Stream<User?> _authState() {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return Stream<User?>.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authState(),
      builder: (context, snapshot) {
        // Firebase still initialising.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _splash();
        }

        final firebaseUser = snapshot.data;

        // No Firebase session → show login.
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        // Firebase user exists → wait for DB profile sync via AuthStore.
        return ListenableBuilder(
          listenable: AuthStore.instance,
          builder: (context, _) {
            final auth = AuthStore.instance;
            if (!auth.isReady) return _splash();
            if (!auth.isLoggedIn) return const LoginScreen();
            // First run: onboard before the shell.
            if (_onboardingSeen == null) return _splash();
            if (!_onboardingSeen!) {
              return OnboardingScreen(
                onDone: () => setState(() => _onboardingSeen = true),
              );
            }
            return const AppShell();
          },
        );
      },
    );
  }

  /// Themed splash: resolves through the active Sakura theme so cold
  /// starts never flash the default light Scaffold in Midnight.
  Widget _splash() {
    return Scaffold(
      backgroundColor: SakuraColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '日常',
              style: SakuraTheme.display(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: SakuraColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              strokeWidth: 2,
              color: SakuraColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
