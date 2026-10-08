import 'package:flutter/services.dart';

/// One haptic language for the whole app — same role, same tick,
/// everywhere. Best-effort and test-safe: every call is guarded, so
/// desktop builds and the widget-test harness (no vibrator) never throw.
///
/// Roles:
/// - [tap] — press confirmations (buttons, toggles, chips).
/// - [select] — selection changes that aren't commits (tabs, steppers).
/// - [confirm] — reward moments (bloom gather, purchase, level-up).
/// - [celebrate] — full reward fanfare: system chime + heavy impact.
///   Prefer [SessionSound.chime] when audio is also wanted; this is the
///   silent twin for places that already play their own sound.
abstract class AppHaptics {
  static Future<void> tap() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // No vibrator — visuals still carry it.
    }
  }

  static Future<void> select() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // No vibrator — visuals still carry it.
    }
  }

  static Future<void> confirm() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // No vibrator — visuals still carry it.
    }
  }

  static Future<void> celebrate() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // No vibrator — visuals still carry it.
    }
  }

  /// Completion "double pulse": a light tap immediately followed by a
  /// medium confirm. Sent as two distinct impacts (no timer), so it is
  /// widget-test safe while reading as a short double buzz on device.
  static Future<void> bloom() async {
    try {
      await HapticFeedback.lightImpact();
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // No vibrator — visuals still carry it.
    }
  }
}
