import 'package:flutter/services.dart';

/// Best-effort end-of-session chime. Uses only framework channels —
/// no audio packages, no assets, works offline. On platforms without
/// a system alert tone this silently degrades to haptics, then to
/// nothing. Never throws into callers (safe in unit tests too).
abstract class SessionSound {
  static Future<void> chime() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // No system tone available — haptics below still carry it.
    }
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Desktop / test harness without a vibrator.
    }
  }
}
