import 'dart:convert';

import 'package:daily_bloom/data/api_client.dart';
import 'package:daily_bloom/game/daily_intention.dart';
import 'package:daily_bloom/widgets/daily_intention_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('same date picks the same target; pool rotates kinds', () {
    final day = DateTime(2026, 3, 10);
    final a = pickIntentionFor(day);
    final b = pickIntentionFor(DateTime(2026, 3, 10, 23, 59));
    expect(a.title, b.title);
    expect(a.goal, b.goal);

    final week = List.generate(
        6, (i) => pickIntentionFor(day.add(Duration(days: i))));
    expect(week.where((t) => t.kind == IntentionKind.tasks).length, 3);
    expect(week.where((t) => t.kind == IntentionKind.focus).length, 3);
  });

  test('progress clamps at 100% and met flips', () {
    // Jan 5 → dayOfYear 4 → tasks goal 2.
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    expect(game.goal, 2);
    game.update(contributionsToday: 1, focusMinutesToday: 0);
    expect(game.fraction, 0.5);
    expect(game.met, isFalse);
    game.update(contributionsToday: 9, focusMinutesToday: 0);
    expect(game.fraction, 1.0);
    expect(game.met, isTrue);
  });

  test('day rollover re-picks the target and resets progress', () {
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    game.update(contributionsToday: 9, focusMinutesToday: 0);
    expect(game.met, isTrue);
    game.update(
        contributionsToday: 9,
        focusMinutesToday: 0,
        now: DateTime(2026, 1, 6));
    // Jan 6 → pool[5] → focus 45: same raw numbers, fresh target.
    expect(game.goal, 45);
    expect(game.met, isFalse);
    expect(game.fraction, 0.0);
  });

  test('pinned-task target keeps goal 1 and quotes the task', () async {
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.setCustomTarget(
      kind: IntentionKind.task,
      goal: 9,
      taskId: 't9',
      taskTitle: 'Ship the beta',
    );
    expect(game.target.kind, IntentionKind.task);
    // "One task" is one task however the stepper was left.
    expect(game.goal, 1);
    expect(game.target.title, 'Finish "Ship the beta"');
    expect(game.target.taskId, 't9');
    expect(game.pinnedTaskId, 't9');
    expect(game.isCustom, isTrue);
    expect(game.met, isFalse);

    // Checking it off anywhere flips today's 1/1 (no refetch needed).
    await game.setPinnedDone(true);
    expect(game.progress, 1);
    expect(game.met, isTrue);
    await game.setPinnedDone(false);
    expect(game.met, isFalse);
  });

  test('several pins: goal is the pick count, progress per task', () async {
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.setCustomTarget(
      kind: IntentionKind.task,
      goal: 1,
      taskIds: ['t1', 't2'],
      taskTitles: ['Ship the beta', 'Weed the garden'],
    );
    expect(game.target.pinCount, 2);
    // The goal is however many were picked, not the stepper value.
    expect(game.goal, 2);
    expect(game.target.title, 'Finish "Ship the beta" & "Weed the garden"');
    expect(game.pinnedTaskIds, ['t1', 't2']);
    expect(game.pinnedTaskId, 't1'); // legacy single-pin reader
    expect(game.fraction, 0.0);

    await game.setPinDone('t1', true);
    expect(game.progress, 1);
    expect(game.fraction, 0.5);
    expect(game.met, isFalse);
    expect(game.pinnedTaskDone, isFalse);

    // The all-or-nothing flag still moves every pin at once.
    game.update(
        contributionsToday: 0, focusMinutesToday: 0, pinnedTaskDone: true);
    expect(game.pinnedTaskDone, isTrue);
    expect(game.progress, 2);
    expect(game.met, isTrue);

    // A refresh for another kind must not wipe the pins.
    game.update(contributionsToday: 3, focusMinutesToday: 0);
    expect(game.pinnedTaskIds, ['t1', 't2']);
    expect(game.met, isTrue);
  });

  test('pins dedupe and cap at five', () async {
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.setCustomTarget(
      kind: IntentionKind.task,
      goal: 4,
      taskIds: ['a', 'b', 'a', 'c', 'd', 'e', 'f'],
      taskTitles: ['A', 'B', 'dupe', 'C', 'D', 'E', 'F'],
    );
    expect(DailyIntentionNotifier.maxPins, 5);
    expect(game.pinnedTaskIds, ['a', 'b', 'c', 'd', 'e']);
    expect(game.pinnedTaskTitles, ['A', 'B', 'C', 'D', 'E']);
    expect(game.goal, 5);
  });

  test('a restart restores every pin and its done set', () async {
    SharedPreferences.setMockInitialValues({
      'bloom_intention_day': '2026-01-05',
      'bloom_intention_kind': 'task',
      'bloom_intention_goal': 2,
      'bloom_intention_task_ids': ['t1', 't2'],
      'bloom_intention_task_titles': ['Ship the beta', 'Weed the garden'],
      'bloom_intention_task_done_ids': ['t2'],
    });
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.loadCustom();
    expect(game.pinnedTaskIds, ['t1', 't2']);
    expect(game.target.title, 'Finish "Ship the beta" & "Weed the garden"');
    expect(game.goal, 2);
    expect(game.progress, 1);
    expect(game.met, isFalse);
  });

  test('the single-pin key shape still loads as one pin', () async {
    SharedPreferences.setMockInitialValues({
      'bloom_intention_day': '2026-01-05',
      'bloom_intention_kind': 'task',
      'bloom_intention_goal': 1,
      'bloom_intention_task_id': 't9',
      'bloom_intention_task_title': 'Ship the beta',
      'bloom_intention_task_done': true,
    });
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.loadCustom();
    expect(game.pinnedTaskIds, ['t9']);
    expect(game.pinnedTaskId, 't9');
    expect(game.pinnedTaskDone, isTrue);
    expect(game.met, isTrue);
  });

  test('task-kind helpers: clamp, title, elapsed labels', () {
    expect(DailyIntentionNotifier.clampGoal(IntentionKind.task, 12), 1);
    expect(DailyIntentionNotifier.clampGoal(IntentionKind.focus, 7), 5);
    expect(DailyIntentionNotifier.taskTitle('   '),
        'Finish 1 pinned task');
    expect(DailyIntentionNotifier.taskTitle('Weed the garden'),
        'Finish "Weed the garden"');
    expect(DailyIntentionNotifier.taskTitlesOf(['A', 'B']),
        'Finish "A" & "B"');
    expect(DailyIntentionNotifier.taskTitlesOf(['A', 'B', 'C']),
        'Finish "A" +2 more');
    expect(DailyIntentionNotifier.customTitle(IntentionKind.task, 3),
        'Finish 3 pinned tasks');
  });

  test('today-scoped progress for a pinned task follows the done flag',
      () async {
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.setCustomTarget(
        kind: IntentionKind.task,
        goal: 1,
        taskId: 't1',
        taskTitle: 'Water the bonsai');
    // Home hands the live done state in with each refresh.
    game.update(contributionsToday: 7, focusMinutesToday: 90,
        pinnedTaskDone: true);
    expect(game.progress, 1);
    expect(game.met, isTrue);
    game.update(contributionsToday: 7, focusMinutesToday: 90,
        pinnedTaskDone: false);
    expect(game.progress, 0);
    expect(game.met, isFalse);
  });

  testWidgets('pinned-task card shows a live task row, not a bare title',
      (tester) async {
    // Mocked prefs: setCustomTarget persists the pin (no platform channels
    // in tests — same convention as widget_test.dart). Reset afterwards so
    // the stored target can't leak into the next test's card.
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.setCustomTarget(
        kind: IntentionKind.task,
        goal: 1,
        taskId: 't1',
        taskTitle: 'Water the bonsai');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyIntentionCard(intention: game),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Headline is the pinned task, and the link row offers the way in.
    expect(find.text('Finish "Water the bonsai"'), findsOneWidget);
    expect(find.text('OPEN TASK'), findsOneWidget);
    expect(find.textContaining('open'), findsWidgets);
  });

  testWidgets('multi-pin card lists one row per picked task', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    await game.setCustomTarget(
      kind: IntentionKind.task,
      goal: 2,
      taskIds: ['t1', 't2'],
      taskTitles: ['Water the bonsai', 'Weed the garden'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyIntentionCard(intention: game),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // One row per pin — the title rides the row when there is more than
    // one, since the headline can only quote so much.
    expect(find.text('Water the bonsai'), findsOneWidget);
    expect(find.text('Weed the garden'), findsOneWidget);
    expect(find.text('OPEN TASK'), findsNWidgets(2));
    expect(find.text('0/2'), findsOneWidget);
  });

  testWidgets('card never auto-fires; tap gathers once per day',
      (tester) async {
    final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
    var fires = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyIntentionCard(
            intention: game,
            onTargetMet: () => fires++,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(fires, 0);

    // Meeting the target shows the fulfilled card but fires nothing.
    game.update(contributionsToday: 5, focusMinutesToday: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(fires, 0);
    expect(find.text('Your bloom is ready'), findsOneWidget);

    // Tapping gathers exactly once, however often repeated.
    await tester.tap(find.text('Your bloom is ready'));
    await tester.pump();
    expect(fires, 1);
    await tester.tap(find.text('Your bloom is ready'));
    await tester.pump();
    expect(fires, 1);

    // Next day meeting its own target gathers once more.
    game.update(
        contributionsToday: 0,
        focusMinutesToday: 99,
        now: DateTime(2026, 1, 6));
    await tester.pump();
    expect(fires, 1);
    await tester.tap(find.text('Your bloom is ready'));
    await tester.pump();
    expect(fires, 2);
    expect(tester.takeException(), isNull);
  });

  group('trackAsTask (intention→task)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    BloomApi mockApi(void Function() onPost) {
      return BloomApi(MockClient((req) async {
        expect(req.method, 'POST');
        onPost();
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response.bytes(
            utf8.encode(jsonEncode({
              'id': 'srv-1',
              'title': body['title'],
              'tag': body['tag'],
              'status': 'todo',
            })),
            201,
            headers: {'content-type': 'application/json'});
      }));
    }

    test('plants the target as a pinned Intention task', () async {
      // Jan 5 → tasks kind (pool), per the rotation test above.
      final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
      var posts = 0;
      final t = await game.trackAsTask(api: mockApi(() => posts++));
      expect(posts, 1);
      expect(t, isNotNull);
      expect(t!.id, 'srv-1');
      expect(t.tag, 'Intention');
      // Loop closed: the card now counts this exact pin.
      expect(game.target.kind, IntentionKind.task);
      expect(game.pinnedTaskIds, ['srv-1']);
      expect(game.trackedTaskId, 'srv-1');
    });

    test('second tap plants nothing (idempotent)', () async {
      final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
      var posts = 0;
      final api = mockApi(() => posts++);
      expect(await game.trackAsTask(api: api), isNotNull);
      expect(await game.trackAsTask(api: api), isNull);
      expect(posts, 1);
    });

    test('pin-kind targets have nothing to plant', () async {
      final game = DailyIntentionNotifier(now: DateTime(2026, 1, 5));
      var posts = 0;
      await game.setCustomTarget(
          kind: IntentionKind.task, goal: 1, taskIds: ['x'], taskTitles: ['X']);
      expect(await game.trackAsTask(api: mockApi(() => posts++)), isNull);
      expect(posts, 0);
    });
  });
}
