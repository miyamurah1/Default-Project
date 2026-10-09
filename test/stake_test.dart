import 'package:daily_bloom/game/bloom_engine.dart';
import 'package:daily_bloom/game/gamification_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stake loss math is capped', () {
    expect(BloomEngine.stakeLossFor(0), 0);
    expect(BloomEngine.stakeLossFor(1), 10);
    expect(BloomEngine.stakeLossFor(3), 30);
    expect(BloomEngine.stakeLossFor(9), 30);
  });

  test('settle keeps finished, wilts the rest', () {
    final game = GamificationStateNotifier();
    game.addXp(500);
    game.stakeDay(['a', 'b', 'c']);
    final r = game.settleDay({'a', 'b'}, {'a', 'b', 'c'});
    expect(r.kept, 2);
    expect(r.wiltedCount, 1);
    expect(r.lost, 10);
    expect(game.totalXp, 490);
    expect(game.wilted, isTrue);
    expect(game.stakedIds, isEmpty);
  });

  test('deleted tasks are exempt, levels never drop', () {
    final game = GamificationStateNotifier();
    game.addXp(100); // exactly L2 base
    game.stakeDay(['gone', 'open']);
    final r = game.settleDay({}, {'open'});
    expect(r.lost, 10);
    // Floored at the level base — wilt, never de-level.
    expect(game.totalXp, BloomEngine.totalXpForLevel(game.level));
  });

  test('clean sweep has no wilt, completion clears wilt', () {
    final game = GamificationStateNotifier();
    game.addXp(500);
    game.stakeDay(['a']);
    final r = game.settleDay({'a'}, {'a'});
    expect(r.lost, 0);
    expect(game.wilted, isFalse);
    game.stakeDay(['b']);
    game.settleDay({}, {'b'});
    expect(game.wilted, isTrue);
    game.registerTaskCompletion();
    expect(game.wilted, isFalse);
  });

  test('third tired morning is forgiven and mercy-resets', () {
    final game = GamificationStateNotifier();
    game.addXp(500);
    game.stakeDay(['a']);
    game.settleDay({}, {'a'});
    expect(game.wiltStreak, 1);
    game.stakeDay(['b']);
    game.settleDay({}, {'b'});
    expect(game.wiltStreak, 2);
    game.stakeDay(['c']);
    final r = game.settleDay({}, {'c'});
    expect(r.rested, isTrue);
    expect(r.lost, 0);
    expect(game.totalXp, 500 - 10 - 10);
    expect(game.wiltStreak, 0);
    expect(game.wilted, isFalse);
  });

  test('clean sweep resets the wilt streak', () {
    final game = GamificationStateNotifier();
    game.addXp(500);
    game.stakeDay(['a']);
    game.settleDay({}, {'a'});
    expect(game.wiltStreak, 1);
    game.stakeDay(['b']);
    game.settleDay({'b'}, {'b'});
    expect(game.wiltStreak, 0);
  });

  test('completions count today, nudge fires once', () {
    final game = GamificationStateNotifier();
    expect(game.todayCompletions, 0);
    game.registerTaskCompletion();
    game.registerTaskCompletion();
    game.registerTaskCompletion();
    expect(game.todayCompletions, 3);
    expect(game.reviewNudgedToday, isFalse);
    game.markReviewNudged();
    expect(game.reviewNudgedToday, isTrue);
  });
}
