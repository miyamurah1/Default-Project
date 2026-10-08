import 'package:flutter_test/flutter_test.dart';
import 'package:daily_bloom/game/game.dart';

void main() {
  test('debugFullBloom maxes profile to Sakura Lv100', () {
    final game = GamificationStateNotifier();
    game.debugFullBloom();
    expect(game.level, 100);
    expect(game.rank, BloomRank.sakura);
    expect(game.rankName, 'Sakura Bloom');
    expect(game.comboCount, 5);
    expect(game.streak, 12);
    expect(game.levelProgress, 1.0);
    // Same formula Home uses for the season strip.
    expect((game.totalXp ~/ 200).clamp(0, 5), 5);
  });
}
