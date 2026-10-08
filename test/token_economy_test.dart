// Token economy: streak multipliers, tiers, theme ramp, and the
// award/spend flows through the central gamification balance.
import 'package:daily_bloom/game/gamification_state.dart';
import 'package:daily_bloom/game/token_economy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('multiplierForStreak tiers', () {
    expect(TokenEconomyManager.multiplierForStreak(0), 1.0);
    expect(TokenEconomyManager.multiplierForStreak(3), 1.0);
    expect(TokenEconomyManager.multiplierForStreak(4), 1.2);
    expect(TokenEconomyManager.multiplierForStreak(8), 1.5);
    expect(TokenEconomyManager.multiplierForStreak(15), 2.0);
    expect(TokenEconomyManager.multiplierForStreak(30), 2.5);
  });

  test('tierLabel tiers', () {
    expect(TokenEconomyManager.tierLabel(0), 'Seedling');
    expect(TokenEconomyManager.tierLabel(4), 'Sprout');
    expect(TokenEconomyManager.tierLabel(8), 'Lotus');
    expect(TokenEconomyManager.tierLabel(15), 'Sakura');
    expect(TokenEconomyManager.tierLabel(30), 'Full Bloom');
  });

  test('specMultiplierForStreak ramps through the gap', () {
    expect(TokenEconomyManager.specMultiplierForStreak(0), 1.0);
    expect(TokenEconomyManager.specMultiplierForStreak(3), 1.25);
    expect(TokenEconomyManager.specMultiplierForStreak(8), 1.35);
    expect(TokenEconomyManager.specMultiplierForStreak(14), 1.5);
  });

  test('BloomThemeModel exposes the 6-step heat ramp', () {
    final m = BloomThemeModel.fromId('midnight');
    expect(m.id, 'midnight');
    expect(m.heatmapColors.length, 6);
    expect(m.heatColor(0), m.heatmapColors[0]);
    expect(m.heatColor(5), m.heatmapColors[5]);
    expect(m.heatColor(-1), m.heatmapColors[0]);
    expect(m.heatColor(99), m.heatmapColors[0]);
    expect(BloomThemeModel.fromActive().id, isNotEmpty);
  });

  test('awardTokens applies the spec multiplier and tracks totals', () {
    final eco = TokenEconomyManager.instance;
    final beforeTokens = GamificationStateNotifier.instance.tokens;
    final beforeEarned = eco.totalEarned;

    final awarded = eco.awardTokens(10, 14); // 1.5x -> 15

    expect(awarded, 15);
    expect(GamificationStateNotifier.instance.tokens, beforeTokens + 15);
    expect(eco.totalEarned, beforeEarned + 15);
  });

  test('onHabitComplete applies the habit streak multiplier', () {
    final eco = TokenEconomyManager.instance;
    final before = GamificationStateNotifier.instance.tokens;

    final awarded = eco.onHabitComplete(baseTokens: 5, streakDays: 8); // 1.5x → 8

    expect(awarded, 8);
    expect(GamificationStateNotifier.instance.tokens, before + 8);
  });

  test('spend respects the balance', () {
    final eco = TokenEconomyManager.instance;
    GamificationStateNotifier.instance.addTokens(20);

    final before = GamificationStateNotifier.instance.tokens;
    expect(eco.spend(5), isTrue);
    expect(GamificationStateNotifier.instance.tokens, before - 5);
    expect(eco.spend(10000000), isFalse, reason: 'insufficient balance');
  });

  test('load restores persisted totals without throwing', () async {
    final eco = TokenEconomyManager.instance;
    await eco.load();
    expect(eco.totalEarned, greaterThanOrEqualTo(0));
    expect(eco.totalSpent, greaterThanOrEqualTo(0));
  });
}
