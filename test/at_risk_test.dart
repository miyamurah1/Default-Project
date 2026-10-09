import 'package:daily_bloom/data/habit_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String key(DateTime d) => HabitStore.dayKey(d);

  Habit habit(String id, String name, Map<String, num> log,
          {bool paused = false}) =>
      Habit(id: id, name: name, log: log, paused: paused);

  test('at-risk means streak alive but not done today', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final live = habit('a', 'Read', {key(yesterday): 1});
    expect(live.streak, 1);
    final risks = HabitStore.atRisk([live], now);
    expect(risks.map((h) => h.id), ['a']);
  });

  test('done today and paused habits are safe', () {
    final now = DateTime.now();
    final done = habit('d', 'Gym', {key(now): 1});
    final paused = habit(
        'p', 'Meditate', {key(now.subtract(const Duration(days: 1))): 1},
        paused: true);
    expect(HabitStore.atRisk([done, paused], now), isEmpty);
  });

  test('longest streak first, max three', () {
    final now = DateTime.now();
    Map<String, num> run(int days) => {
          for (var i = 1; i <= days; i++)
            key(now.subtract(Duration(days: i))): 1,
        };
    final habits = [
      habit('s1', 'One', run(1)),
      habit('s5', 'Five', run(5)),
      habit('s3', 'Three', run(3)),
      habit('s2', 'Two', run(2)),
    ];
    final risks = HabitStore.atRisk(habits, now);
    expect(risks.map((h) => h.id).toList(), ['s5', 's3', 's2']);
  });
}
