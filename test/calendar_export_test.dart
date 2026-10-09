import 'package:daily_bloom/data/calendar_export.dart';
import 'package:daily_bloom/data/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Task task(String id,
          {String title = 'T',
          DateTime? dueAt,
          DateTime? completedAt,
          String status = 'todo'}) =>
      Task(
          id: id,
          title: title,
          tag: 'Work',
          folder: 'Productivity',
          status: status,
          dueAt: dueAt,
          completedAt: completedAt);

  test('frames a valid calendar with one event per dated task', () {
    final ics = buildIcs([
      task('a', title: 'Ship it', dueAt: DateTime.utc(2026, 10, 7, 9, 30)),
      task('b', title: 'No date'),
    ], now: DateTime.utc(2026, 10, 6, 12));
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics, contains('END:VCALENDAR'));
    expect(ics, contains('UID:a@dailybloom'));
    expect(ics, contains('DTSTART:20261007T093000Z'));
    expect(ics, contains('SUMMARY:Ship it'));
    expect(ics, contains('DESCRIPTION:Productivity · Work'));
    expect(ics, contains('DTSTAMP:20261006T120000Z'));
    expect(ics.contains('UID:b@'), isFalse);
    expect(datedCount([task('a', dueAt: DateTime.utc(2026, 1, 1)), task('b')]), 1);
  });

  test('escapes commas, semicolons, newlines, backslashes', () {
    final ics = buildIcs([
      task('a',
          title: 'Plan; party, go\nbig \\ now',
          dueAt: DateTime.utc(2026, 10, 7)),
    ]);
    expect(ics, contains(r'SUMMARY:Plan\; party\, go\nbig \\ now'));
  });

  test('completed stamp only when finished', () {
    final done = buildIcs([
      task('a',
          dueAt: DateTime.utc(2026, 10, 7),
          completedAt: DateTime.utc(2026, 10, 6, 18),
          status: 'done'),
      task('b', dueAt: DateTime.utc(2026, 10, 8), status: 'todo'),
    ]);
    expect(done.split('COMPLETED:').length - 1, 1);
    expect(done, contains('COMPLETED:20261006T180000Z'));
  });

  test('empty list is a valid empty calendar', () {
    final ics = buildIcs([]);
    expect(ics, contains('BEGIN:VCALENDAR'));
    expect(ics.contains('BEGIN:VEVENT'), isFalse);
    expect(datedCount([]), 0);
  });

  test('plan blocks lay back-to-back from the start hour', () {
    final ics = buildPlanBlocks(
      const [
        PlanBlock(id: 'a', title: 'Deep work', minutes: 50),
        PlanBlock(id: 'b', title: 'Email triage', minutes: 25),
      ],
      day: DateTime(2026, 10, 7),
      startHour: 14,
    );
    expect(ics, contains('UID:plan-a@dailybloom'));
    expect(ics, contains('DURATION:PT50M'));
    expect(ics, contains('SUMMARY:Deep work'));
    // Second block starts after 50 min + 5 min breather (15:05 local).
    expect(ics, contains('DURATION:PT25M'));
  });
}
