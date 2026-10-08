import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../game/game.dart';
import 'data/api_client.dart';
import 'data/auth_store.dart';
import 'data/energy_store.dart';
import 'data/reminders.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'theme/sakura_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase before anything else.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Paint the last-used theme before the first frame — no flash.
  await ThemeStore.instance.preload();

  // Mindful gamification: restore XP / tokens / streak before first frame.
  await GamificationStateNotifier.instance.load();
  GamificationStateNotifier.instance.markDailyActive();

  // Energy labels are local-first: restore before first frame so cards
  // never flash unlabeled.
  await EnergyStore.instance.load();

  // Reminder preference restores silently; scheduling re-arms inside
  // init when enabled (the OS drops alarms on reboot/update).
  await ReminderService.instance.load();
  await ReminderService.instance.init();

  runApp(const DailyBloomApp());

  // Restore profile from Firebase auth state. If already signed in, the
  // listener in AuthStore.restore() fires immediately and syncs the theme.
  AuthStore.instance.restore().then((_) {
    if (AuthStore.instance.isLoggedIn) {
      ThemeStore.instance.sync(() => BloomApi().fetchStore());
    }
  });
}

/// Daily Bloom root — Sakura theme + AuthGate.
///
/// AuthGate shows LoginScreen when logged out, AppShell when logged in.
/// The whole MaterialApp rebuilds when the theme changes (live skins).
class DailyBloomApp extends StatelessWidget {
  const DailyBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (_, __) => MaterialApp(
        title: 'Daily Bloom',
        debugShowCheckedModeBanner: false,
        theme: SakuraTheme.buildTheme(),
        // Cap system text scaling at 1.3x: the layout stays legible for
        // accessibility without the sub-12px labels blowing out cards.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
            ),
            child: child!,
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}
