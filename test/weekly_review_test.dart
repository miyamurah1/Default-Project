import 'package:daily_bloom/data/api_client.dart';
import 'package:daily_bloom/data/habit_store.dart';
import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/data/weekly_review.dart';
import 'package:daily_bloom/screens/review_screen.dart';
import 'package:daily_bloom/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Wednesday 2026-09-30 → week Mon Sep 28 – Sun Oct 4.
final _wed = DateTime(2026, 9, 30);
String _day(DateTime d) => HabitStore.dayKey(d);
DateTime _d(int weekdayOffset) =>
    DateTime(2026, 9, 28).add(Duration(days: weekdayOffset));

Task _done(String id, DateTime at) => Task(
      id: id,
      title: 't $id',
      tag: 'Work',
      status: 'done',
      completedAt: at,
    );

void main() {
  test('week bounds and label', () {
    expect(reviewWeekStart(_wed), DateTime(2026, 9, 28));
    expect(reviewWeekLabel(_wed), 'Sep 28 – Oct 4');
  });

  test('empty inputs stay honestly empty', () {
    final r = buildWeeklyReview(
      done: const [],
      ins: const Insights(),
      habits: const [],
      now: _wed,
    );
    expect(r.isEmpty, isTrue);
    expect(r.doneCount, 0);
    expect(r.verdict, contains('No signal'));
  });

  test('completions group by day, out-of-week ignored', () {
    final r = buildWeeklyReview(
      done: [
        _done('a', _d(0).add(const Duration(hours: 9))),
        _done('b', _d(0).add(const Duration(hours: 18))),
        _done('c', _d(3).add(const Duration(hours: 12))),
        _done('old', _d(0).subtract(const Duration(days: 1))), // Sun before
        _done('next', _d(0).add(const Duration(days: 7))), // next Mon
        const Task(id: 'nodate', title: 'x', tag: 'y', status: 'done'),
      ],
      ins: const Insights(),
      habits: const [],
      now: _wed,
    );
    expect(r.doneCount, 3);
    expect(r.bestDay, 'Mon');
    expect(r.bestDayCount, 2);
    expect(r.activeDays, 2);
    expect(r.verdict, contains('3 done'));
    expect(r.verdict, contains('Mon carried the week (2)'));
  });

  test('focus days join active days; zeros and junk ignored', () {
    final r = buildWeeklyReview(
      done: [_done('a', _d(2).add(const Duration(hours: 10)))],
      ins: Insights(focusDays: [
        FocusDay(date: _day(_d(2)), minutes: 30, sessions: 1),
        FocusDay(date: _day(_d(4)), minutes: 45, sessions: 2),
        FocusDay(date: _day(_d(5)), minutes: 0, sessions: 0),
        const FocusDay(date: 'not-a-date', minutes: 99),
      ], focusMinutes7: 75, focusSessions7: 3),
      habits: const [],
      now: _wed,
    );
    expect(r.focusMinutes, 75);
    expect(r.focusSessions, 3);
    // Wed (done+focus) + Fri (focus only).
    expect(r.activeDays, 2);
  });

  test('top tag picks the best rate with finishes', () {
    final r = buildWeeklyReview(
      done: [_done('a', _d(1).add(const Duration(hours: 10)))],
      ins: const Insights(byTag: [
        SplitStat(name: 'Weak', total: 5, done: 1),
        SplitStat(name: 'Strong', total: 4, done: 4),
        SplitStat(name: 'Empty', total: 0, done: 0),
      ]),
      habits: const [],
      now: _wed,
    );
    expect(r.topTag, 'Strong');
    expect(r.verdict, contains('Strong led at 100%'));
  });

  test('kept means 4+ days; paused habits sit out', () {
    Map<String, num> logDays(List<int> offsets) => {
          for (final o in offsets) _day(_d(o)): 1,
        };
    final r = buildWeeklyReview(
      done: const [],
      ins: const Insights(),
      habits: [
        Habit(id: 'k', name: 'kept', log: logDays([0, 1, 2, 3])),
        Habit(id: 's', name: 'slack', log: logDays([0, 1])),
        Habit(id: 'p', name: 'paused', paused: true, log: logDays([0, 1, 2, 3, 4])),
      ],
      now: _wed,
    );
    expect(r.habitsTotal, 2);
    expect(r.habitsKept, 1);
    expect(r.isEmpty, isFalse);
    expect(r.verdict, contains('1 of 2 habits kept'));
  });

  testWidgets('review offline is honest', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await tester.pumpWidget(const MaterialApp(home: ReviewScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text("You're offline"), findsOneWidget);
    expect(find.textContaining('WEEKLY REVIEW'), findsOneWidget);
  });

  test('share text mirrors the numbers', () {
    final r = buildWeeklyReview(
      done: [_done('a', _d(1).add(const Duration(hours: 10)))],
      ins: const Insights(focusMinutes7: 90, focusSessions7: 4),
      habits: const [],
      now: _wed,
    );
    final text = shareTextFor(r);
    expect(text, contains('Sep 28'));
    expect(text, contains('1 done'));
    expect(text, contains('90 min focused'));
  });

  testWidgets('share card paints the review', (tester) async {
    final r = buildWeeklyReview(
      done: [_done('a', _d(1).add(const Duration(hours: 10)))],
      ins: const Insights(focusMinutes7: 90, focusSessions7: 4),
      habits: const [],
      now: _wed,
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ShareCard(review: r))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('MY WEEK IN BLOOM'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.textContaining('Daily Bloom'), findsOneWidget);
  });
}
