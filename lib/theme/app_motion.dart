import 'package:flutter/material.dart';

/// Unified motion tokens — one duration + curve language across the app.
///
/// Before: each widget picked its own `Duration(milliseconds: X)` and
/// `Curves.*` in isolation (entrance 450ms here, route 220ms there,
/// tap 120ms elsewhere). That reads as "assembled" rather than designed.
///
/// After: every scale / fade / slide / route reads from here. Tweak one
/// constant, feel it everywhere. Mobile 60fps is preserved — these are
/// just `const Duration` / `Curve` values, no extra controllers.
///
/// Usage:
/// ```dart
/// AnimatedScale(duration: AppMotion.press, curve: AppMotion.pressCurve, ...)
/// SakuraPageRoute — uses AppMotion.pageEnter / pageExit
/// Entrance — uses AppMotion.entrance / entranceCurve
/// ```
abstract class AppMotion {
  // ── Durations ─────────────────────────────────────────────
  /// List / header entrance (fade + 14px rise).
  static const entrance = Duration(milliseconds: 450);

  /// Page push (SakuraPageRoute).
  static const pageEnter = Duration(milliseconds: 220);
  static const pageExit = Duration(milliseconds: 200);

  /// Tap / press spring.
  static const press = Duration(milliseconds: 140);
  static const tap = Duration(milliseconds: 120);

  /// Bottom-nav selection.
  static const nav = Duration(milliseconds: 200);

  /// Stagger step for lists.
  static const staggerStep = Duration(milliseconds: 40);
  static const staggerCap = Duration(milliseconds: 200);

  /// Shimmer pulse.
  static const shimmer = Duration(milliseconds: 1400);

  /// Glow breathing (theme card legendary + daily intention).
  static const glow = Duration(milliseconds: 2600);
  static const celebration = Duration(milliseconds: 2200);

  /// Hero flight for task → timer.
  static const hero = Duration(milliseconds: 420);

  /// Reward burst (level-up petals).
  static const burst = Duration(milliseconds: 900);

  /// Snackbar / mini-player slide.
  static const snackbar = Duration(milliseconds: 280);

  /// State toggles: checkbox fills, container recolors, switchers,
  /// saturation crossfades, quote crossfades. One calm beat.
  static const toggle = Duration(milliseconds: 240);

  /// Progress fills and count-ups: bars, rings, % tallies.
  static const progress = Duration(milliseconds: 500);

  /// Celebration bounce (completion squash-and-settle).
  static const bounce = Duration(milliseconds: 300);

  /// One-shot drift-and-fade floaters ("+50 XP" labels).
  static const floater = Duration(milliseconds: 1200);

  /// Slot-machine counter scrolls.
  static const counter = Duration(milliseconds: 1500);

  /// Hold time after the burst peaks before auto-dismiss.
  static const burstHold = Duration(milliseconds: 650);

  /// In-page scroll glides (section jumps, carousels).
  static const scroll = Duration(milliseconds: 350);
  static const scrollCurve = Curves.easeOutCubic;

  /// Board paging glide: slow in-out reads smoother than a snap.
  static const glide = Duration(milliseconds: 500);
  static const glideCurve = Curves.easeInOutCubic;

  /// Onboarding page turns + sheet spring-ins.
  static const pageTurn = Duration(milliseconds: 320);
  static const pageTurnCurve = Curves.easeOutCubic;

  // ── Curves ────────────────────────────────────────────────
  static const entranceCurve = Curves.easeOut;
  static const entranceSlideCurve = Curves.easeOutCubic;

  static const pageCurve = Curves.easeOutCubic;
  static const pageReverseCurve = Curves.easeInCubic;

  static const pressCurve = Curves.easeOutBack;
  static const tapCurve = Curves.easeOut;

  /// Soft settle for counters / toasts.
  static const settleCurve = Curves.easeOutCubic;
  static const settleInCurve = Curves.easeInOut;

  /// State toggles: calm in-out, no spring.
  static const toggleCurve = Curves.easeInOut;

  /// Progress fills: fast launch, gentle settle.
  static const progressCurve = Curves.easeOutCubic;

  /// Celebration bounce: springy overshoot.
  static const bounceCurve = Curves.easeOutBack;

  /// Floater drift: steady rise.
  static const floaterCurve = Curves.easeOutCubic;

  /// Counter scrolls: fast launch, gentle settle.
  static const counterCurve = Curves.easeOutCubic;

  /// Hero flight shimmer.
  static const heroCurve = Curves.easeOutCubic;

  // ── Geometry ──────────────────────────────────────────────
  static const double entranceRise = 14;
  static const double pressScale = 0.94;
  static const double tapScale = 0.96;
  static const double pageScaleFrom = 0.97;

  /// First N items animate in a stagger; rest appear instantly.
  static const int staggerMaxAnimated = 8;

  // ── Accessibility ─────────────────────────────────────────
  /// True when the platform asks for reduced motion (OS "reduce motion"
  /// / disable animations). Decorative motion should skip animating —
  /// feedback (haptics, colour) still applies.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
