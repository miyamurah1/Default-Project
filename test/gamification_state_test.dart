// Gamification state: XP/level, combo chaining, daily ritual tokens,
// streak transitions, and the debug helpers. Fresh instances per test so
// the app singleton (and its combo timer) is never disturbed.
import 'package:daily_bloom/game/bloom_engine.dart';
import 'package:daily_bloom/game/gamification_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GamificationStateNotifier game;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    game = GamificationStateNotifier();
  });

  tearDown(() => game.dispose());

  test('addXp raises level through the engine curve', () {
    expect(game.level, 1);
    game.addXp(BloomEngine.totalXpForLevel(3));
    expect(game.level, greaterThanOrEqualTo(3));
    expect(game.xpIntoLevel, greaterThanOrEqualTo(0));
    expect(game.xpNeeded, greaterThan(0));
    expect(game.rankName, isNotEmpty);
  });

  test('completions chain into a live combo with bonus XP', () {
    final first = game.registerTaskCompletion();
    expect(game.comboCount, 1);
    expect(first, BloomEngine.xpForCombo(BloomEngine.baseTaskXp, 1));

    final second = game.registerTaskCompletion();
    expect(game.comboCount, 2);
    // A combo chain never grants less than the first hit.
    expect(second, greaterThanOrEqualTo(first));
    expect(game.isComboLive, isTrue);
    expect(game.comboExpiresAt, isNotNull);
  });

  test('daily ritual drops tokens and reports the roll', () {
    final before = game.tokens;
    final reward = game.claimDailyRitual();
    expect(game.tokens, before + reward.tokens);
    expect(reward.tokens, greaterThan(0));
  });

  test('streak: first day, consecutive day, and a broken gap', () {
    game.markDailyActive(DateTime(2026, 1, 1));
    expect(game.streak, 1);

    game.markDailyActive(DateTime(2026, 1, 1)); // same day → no-op
    expect(game.streak, 1);

    game.markDailyActive(DateTime(2026, 1, 2)); // next day → +1
    expect(game.streak, 2);

    game.markDailyActive(DateTime(2026, 1, 5)); // gap → reset
    expect(game.streak, 1);
  });

  test('streak progresses through a 7-day milestone week', () {
    // Milestone haptics (7/30/100) ride on markDailyActive — the count
    // path must reach them exactly, no skips or double-counts.
    for (var d = 1; d <= 7; d++) {
      game.markDailyActive(DateTime(2026, 2, d));
      expect(game.streak, d);
    }
    // Day 8 continues past the milestone without resetting.
    game.markDailyActive(DateTime(2026, 2, 8));
    expect(game.streak, 8);
  });

  test('setStreak clamps negatives to zero', () {
    game.setStreak(-4);
    expect(game.streak, 0);
    game.setStreak(9);
    expect(game.streak, 9);
  });

  test('tokens: add and spend respect the balance', () {
    game.addTokens(30);
    expect(game.spendTokens(10), isTrue);
    expect(game.tokens, 20);
    expect(game.spendTokens(100), isFalse);
    expect(game.tokens, 20);
  });

  test('debugFullBloom and debugReset set expected extremes', () {
    game.debugFullBloom();
    expect(game.level, BloomEngine.maxLevel);
    expect(game.comboCount, 5);
    expect(game.streak, greaterThanOrEqualTo(12));

    game.debugReset();
    expect(game.totalXp, 0);
    expect(game.tokens, 0);
    expect(game.streak, 1);
    expect(game.comboCount, 0);
  });

  test('load restores persisted xp / tokens / streak', () async {
    SharedPreferences.setMockInitialValues({
      'bloom_game_xp': 250,
      'bloom_game_tokens': 42,
      'bloom_game_streak': 6,
    });
    final restored = GamificationStateNotifier();
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.totalXp, 250);
    expect(restored.tokens, 42);
    expect(restored.streak, 6);
  });
}
