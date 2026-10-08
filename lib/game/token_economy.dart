import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/sakura_theme.dart';
import 'bloom_engine.dart';
import 'gamification_state.dart';

// ---------------------------------------------------------------------------
// MODULE 2A: TokenEconomyManager
// ---------------------------------------------------------------------------

/// Manages the habit-aware token economy with streak-based multipliers.
///
/// Integrates with [GamificationStateNotifier] for XP and token
/// operations — this layer adds streak multiplier logic specific to
/// habits (distinct from the task-flow combo system).
///
/// ```dart
/// final eco = TokenEconomyManager.instance;
/// eco.onHabitComplete(streakDays: 12); // → 1.5× multiplier
/// ```
class TokenEconomyManager extends ChangeNotifier {
  static final TokenEconomyManager instance = TokenEconomyManager._();
  TokenEconomyManager._();

  static const _kTotalEarned = 'bloom_eco_total_earned';
  static const _kTotalSpent = 'bloom_eco_total_spent';

  int _totalEarned = 0;
  int _totalSpent = 0;

  int get totalEarned => _totalEarned;
  int get totalSpent => _totalSpent;

  /// Shortcut: the live token balance is owned by [GamificationStateNotifier].
  int get balance => GamificationStateNotifier.instance.tokens;

  // --- Streak Multiplier Logic ---

  /// Returns the token multiplier for a given streak length.
  ///
  /// | Streak (days) | Multiplier |
  /// |---------------|------------|
  /// | 0             | 1.0×       |
  /// | 1–3           | 1.0×       |
  /// | 4–7           | 1.2×       |
  /// | 8–14          | 1.5×       |
  /// | 15–29         | 2.0×       |
  /// | 30+           | 2.5×       |
  static double multiplierForStreak(int streakDays) {
    if (streakDays >= 30) return 2.5;
    if (streakDays >= 15) return 2.0;
    if (streakDays >= 8) return 1.5;
    if (streakDays >= 4) return 1.2;
    return 1.0;
  }

  /// Returns a human-readable label for the multiplier tier.
  static String tierLabel(int streakDays) {
    if (streakDays >= 30) return 'Full Bloom';
    if (streakDays >= 15) return 'Sakura';
    if (streakDays >= 8) return 'Lotus';
    if (streakDays >= 4) return 'Sprout';
    return 'Seedling';
  }

  /// Spec-tier multiplier: 1x for 0-2 days, 1.25x for 3-7 days,
  /// 1.5x for 14+ days. The 8-13 gap ramps at 1.35x so progress
  /// never feels flat between Sprout and Lotus.
  static double specMultiplierForStreak(int streakDays) {
    if (streakDays >= 14) return 1.5;
    if (streakDays >= 8) return 1.35;
    if (streakDays >= 3) return 1.25;
    return 1.0;
  }

  /// Spec entry-point: `awardTokens(baseAmount, currentStreak)`.
  /// Applies the mindful streak multiplier above, routes through the
  /// central gamification balance, and returns the awarded total.
  int awardTokens(int baseAmount, int currentStreak) {
    final mult = specMultiplierForStreak(currentStreak);
    final tokens = (baseAmount * mult).round();
    GamificationStateNotifier.instance.addTokens(tokens);
    _totalEarned += tokens;
    _persist();
    notifyListeners();
    return tokens;
  }

  /// Call when a habit is completed. Awards tokens with streak multiplier
  /// and grants XP via the gamification system.
  ///
  /// Returns the total tokens awarded (after multiplier).
  int onHabitComplete({
    int baseTokens = 5,
    int streakDays = 0,
    int baseXp = BloomEngine.baseTaskXp,
  }) {
    final mult = multiplierForStreak(streakDays);
    final tokens = (baseTokens * mult).round();

    // Push through the central gamification system
    GamificationStateNotifier.instance.addTokens(tokens);
    GamificationStateNotifier.instance.registerTaskCompletion(baseXp: baseXp);

    _totalEarned += tokens;
    _persist();
    notifyListeners();

    return tokens;
  }

  /// Attempt to spend tokens. Returns false if insufficient balance.
  bool spend(int amount) {
    final ok = GamificationStateNotifier.instance.spendTokens(amount);
    if (ok) {
      _totalSpent += amount;
      _persist();
      notifyListeners();
    }
    return ok;
  }

  // --- Persistence ---

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalEarned = prefs.getInt(_kTotalEarned) ?? 0;
      _totalSpent = prefs.getInt(_kTotalSpent) ?? 0;
      notifyListeners();
    } catch (_) {
      // First run or offline — keep zeros.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kTotalEarned, _totalEarned);
      await prefs.setInt(_kTotalSpent, _totalSpent);
    } catch (_) {
      // Best-effort.
    }
  }
}

// ---------------------------------------------------------------------------
// MODULE 2B: BloomThemeModel
// ---------------------------------------------------------------------------

/// Extended theme model that includes heatmap color ramps, allowing
/// purchased themes to re-skin the contribution grid.
///
/// This wraps [AppThemeData] and adds the `heatmapColors` array
/// (intensity 1–4 → specific hex codes) so the [YearInFocusWidget]
/// can read colors from the active theme.
class BloomThemeModel {
  final AppThemeData base;

  const BloomThemeModel({required this.base});

  String get id => base.id;
  String get name => base.name;
  String get label => base.label;

  /// The heatmap color ramp for this theme — maps intensity 0..5
  /// to distinct colors. Sourced from the [AppThemeData] heat fields.
  List<Color> get heatmapColors => [
        base.heat0,
        base.heat1,
        base.heat2,
        base.heat3,
        base.heat4,
        base.heatPeak,
      ];

  /// Convenience: resolve a heat level (0-5) to its theme color.
  Color heatColor(int level) {
    if (level < 0 || level >= heatmapColors.length) return heatmapColors[0];
    return heatmapColors[level];
  }

  /// Build a [BloomThemeModel] from the currently active SakuraColors theme.
  factory BloomThemeModel.fromActive() =>
      BloomThemeModel(base: SakuraColors.active);

  /// Build from a known theme id.
  factory BloomThemeModel.fromId(String id) =>
      BloomThemeModel(base: AppThemes.byId(id));
}
