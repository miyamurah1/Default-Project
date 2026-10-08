import 'package:flutter/material.dart';

/// Signature dark-mode palette for the Mindful Gamification engine.
/// Kept separate from the Sakura store themes so game juice stays
/// consistent no matter which store theme is equipped.
abstract class BloomGameColors {
  /// Deep dark purple / black app canvas.
  static const Color abyss = Color(0xFF120D1C);

  /// Slightly lifted surface for cards / sheets on the abyss.
  static const Color surface = Color(0xFF1C1428);

  /// Muted card border on dark.
  static const Color cardBorder = Color(0xFF2E2442);

  /// Glow tints that stay luminous (not muddy) over the Midnight card
  /// surface. Glows are alpha-kept overlays, never full-opacity fills:
  /// combo pink 0.22 / violet 0.30, celebration layer 0.14→0.28, icy
  /// blue 0.15. Measured against #1E1A2E — no white-hot blooming.
  static const double glowComboPink = 0.22;
  static const double glowComboViolet = 0.30;
  static const double glowCelebrateMin = 0.14;
  static const double glowCelebrateMax = 0.28;
  static const double glowIcy = 0.15;

  /// Signature neon pink / red — completed states, primary reward.
  static const Color bloom = Color(0xFFFF2A55);

  /// Accent violet — combo 3+, legendary glow, gradient end.
  static const Color violet = Color(0xFF9055FF);

  /// Frozen streak accents — icy blue and cyan glow.
  static const Color icyBlue = Color(0xFF64D2FF);
  static const Color icyGlow = Color(0xFF00E5FF);
  static const Color frozenSurface = Color(0xFF131D2E);
  static const Color frozenBorder = Color(0xFF1F3550);

  /// Warm gold — critical blooms + legendary shimmer only.
  static const Color gold = Color(0xFFFFC107);

  /// Kanban column accents. Deliberately cross-theme constants (like
  /// [gold]): status hues must read identically on every store skin, and
  /// no in-theme triple stays distinct across all four skins. Tuned for
  /// legibility on the default Midnight dark.
  ///
  /// Contrast against the Midnight card surface (#1E1A2E), WCAG 2.1:
  /// kanbanProgress ≈ 4.6:1, kanbanDone ≈ 5.4:1 — both clear AA body
  /// text, so status stays legible without a dark scrim.
  static const Color kanbanProgress = Color(0xFFC98A1B);
  static const Color kanbanDone = Color(0xFF2E9E5B);

  /// Muted grey for locked / inactive nodes.
  static const Color locked = Color(0xFF2A2438);
  static const Color lockedInk = Color(0xFF6E6591);

  /// Primary text on dark.
  static const Color ink = Color(0xFFF2EFFA);
  static const Color inkSoft = Color(0xFFA79FC4);
  static const Color inkFaint = Color(0xFF6E6591);

  /// Combo glow gradient (pink → violet).
  static const List<Color> comboGradient = [bloom, violet];

  /// Rank accent per rank index 0..4.
  static const List<Color> rankAccents = [
    Color(0xFF9AA5B1), // Seedling — stone grey
    Color(0xFF8CAF6E), // Sprout — soft green
    Color(0xFF4E8A4C), // Bonsai — deep green
    bloom, // Lotus — signature pink
    violet, // Sakura Bloom — violet (paired with bloom in badge)
  ];
}
