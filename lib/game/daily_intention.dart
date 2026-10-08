import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import '../data/auth_store.dart';
import '../data/mock_data.dart';

/// What a daily intention measures. All signals are "today" scoped:
/// - tasks -> today's heatmap contribution count (done tasks + sessions)
/// - focus -> today's focus minutes from the focus summary
/// - task -> the tasks you picked: finish them (and their subtasks)
///   today. One pin or several — the goal is how many you picked.
enum IntentionKind { tasks, focus, task }

/// One day's target: what to do + how much is enough.
/// `taskIds`/`taskTitles` are only set for the pinned-task kind: the
/// tasks picked for today, in pick order.
class DailyTarget {
  final IntentionKind kind;
  final int goal;
  final String title;

  /// Pinned task ids, in the order they were picked.
  final List<String> taskIds;

  /// Titles parallel to [taskIds], so the card can draw a row offline.
  final List<String> taskTitles;

  const DailyTarget({
    required this.kind,
    required this.goal,
    required this.title,
    this.taskIds = const [],
    this.taskTitles = const [],
  });

  /// First pin — the single-task target and every older call site.
  String? get taskId => taskIds.isEmpty ? null : taskIds.first;
  String? get taskTitle => taskTitles.isEmpty ? null : taskTitles.first;

  /// How many tasks today's target asks for (0 for count/focus kinds).
  int get pinCount => taskIds.length;
}

/// Rotating pool — deterministic per calendar day, so every user shares
/// the same intention and it changes at midnight. Gentle range:
/// 2–5 tasks, 15–45 focus minutes.
const _pool = [
  DailyTarget(
      kind: IntentionKind.tasks,
      goal: 3,
      title: 'Complete 3 tasks'),
  DailyTarget(
      kind: IntentionKind.focus,
      goal: 25,
      title: 'Focus for 25 minutes'),
  DailyTarget(
      kind: IntentionKind.tasks,
      goal: 5,
      title: 'Complete 5 tasks'),
  DailyTarget(
      kind: IntentionKind.focus,
      goal: 15,
      title: 'Focus for 15 minutes'),
  DailyTarget(
      kind: IntentionKind.tasks,
      goal: 2,
      title: 'Ease in — finish 2 tasks'),
  DailyTarget(
      kind: IntentionKind.focus,
      goal: 45,
      title: 'Go deep — 45 focus minutes'),
];

/// Pure pick: same date → same target. Testable without IO.
DailyTarget pickIntentionFor(DateTime day) {
  final dayOfYear =
      day.difference(DateTime(day.year, 1, 1)).inDays;
  return _pool[dayOfYear % _pool.length];
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Today's contribution count out of an already-loaded heatmap —
/// lets callers (Home) reuse data instead of refetching.
int heatCountFor(List<HeatDay> heat, DateTime day) {
  final key = _dayKey(day);
  return heat
      .where((h) => _dayKey(h.date.toLocal()) == key)
      .fold<int>(0, (a, h) => a + h.count);
}

/// State for one day's intention. The card observes this and fires
/// `onTargetMet` once at 100%.
///
/// IO lives only in [refresh]; [update] is pure so tests drive the
/// math without a backend.
class DailyIntentionNotifier extends ChangeNotifier {
  DailyIntentionNotifier({DateTime? now})
      : _now = now ?? DateTime.now() {
    // Seed from the same clock tests inject — never the wall clock.
    _target = pickIntentionFor(_now);
  }

  /// App-wide singleton — Home owns the refresh, the card observes.
  static final DailyIntentionNotifier instance =
      DailyIntentionNotifier();

  final BloomApi _api = BloomApi();
  DateTime _now;

  DailyTarget _target = const DailyTarget(
      kind: IntentionKind.tasks, goal: 3, title: 'Complete 3 tasks');

  /// User override ("my target today"): beats the pool pick, but only
  /// on the day it was set. Persisted so it survives restarts.
  DailyTarget? _custom;
  String? _customDay;
  bool _customLoaded = false;

  static const _kDay = 'bloom_intention_day';
  static const _kKind = 'bloom_intention_kind';
  static const _kGoal = 'bloom_intention_goal';

  /// Pinned tasks for the `task` kind, with today's done set. Persisted
  /// alongside the custom target so "my tasks today" survives restarts.
  List<String> _pinnedIds = const [];
  List<String> _pinnedTitles = const [];
  Set<String> _pinnedDoneIds = const {};

  static const _kTaskIds = 'bloom_intention_task_ids';
  static const _kTaskTitles = 'bloom_intention_task_titles';
  static const _kTaskDoneIds = 'bloom_intention_task_done_ids';

  /// intention→task link: the real task created from a count/focus
  /// target ("Track as task"). Day-scoped like the custom target —
  /// tomorrow the button may plant a fresh one, never a duplicate.
  static const _kTrackedId = 'bloom_intention_tracked_id';
  static const _kTrackedDay = 'bloom_intention_tracked_day';
  String? _trackedId;
  String? _trackedDay;

  /// Single-pin keys from before multi-select: read once, then folded
  /// into the list keys above by [_persistPins].
  static const _kTaskId = 'bloom_intention_task_id';
  static const _kTaskTitle = 'bloom_intention_task_title';
  static const _kTaskDone = 'bloom_intention_task_done';

  /// How many tasks one day may pin. Five is a full day; more would turn
  /// the picker (and the card) into a scroll.
  static const maxPins = 5;

  static String customTitle(IntentionKind kind, int goal) =>
      kind == IntentionKind.tasks
          ? 'Complete $goal task${goal == 1 ? '' : 's'}'
          : kind == IntentionKind.focus
              ? 'Focus for $goal minutes'
              : goal <= 1
                  ? 'Finish 1 pinned task'
                  : 'Finish $goal pinned tasks';

  /// Headline for the pinned-task kind: `Finish "Ship the beta"` for one
  /// pin, `Finish "A" & "B"` for two, `Finish "A" +2 more` beyond that.
  static String taskTitlesOf(List<String> titles) {
    final clean = <String>[
      for (final t in titles)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    if (clean.isEmpty) return 'Finish 1 pinned task';
    if (clean.length == 1) return 'Finish "${clean.first}"';
    if (clean.length == 2) return 'Finish "${clean[0]}" & "${clean[1]}"';
    return 'Finish "${clean.first}" +${clean.length - 1} more';
  }

  /// Single-pin shorthand, kept for the one-task call sites.
  static String taskTitle(String title) => taskTitlesOf([title]);

  static int clampGoal(IntentionKind kind, int goal) {
    if (kind == IntentionKind.task) return 1;
    if (kind == IntentionKind.tasks) return goal.clamp(1, 20);
    return (goal ~/ 5).clamp(1, 36) * 5;
  }

  /// Ids and titles are one list of pins internally; they are split only
  /// for storage. Dedupe on id, drop blanks, cap at [maxPins], and keep
  /// each title beside its own id.
  static ({List<String> ids, List<String> titles}) pairPins(
      List<String> ids, List<String> titles) {
    final outIds = <String>[];
    final outTitles = <String>[];
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i].trim();
      if (id.isEmpty || outIds.contains(id)) continue;
      outIds.add(id);
      outTitles.add(i < titles.length ? titles[i].trim() : '');
      if (outIds.length == maxPins) break;
    }
    return (
      ids: List.unmodifiable(outIds),
      titles: List.unmodifiable(outTitles),
    );
  }

  DailyTarget get _effective {
    if (_custom != null && _customDay == _dayKey(_now)) {
      return _custom!;
    }
    return pickIntentionFor(_now);
  }

  /// True when today's target is the user's own, not the suggested one.
  bool get isCustom =>
      _custom != null && _customDay == _dayKey(_now);

  /// Tasks pinned for today, in pick order (empty for count/focus).
  List<String> get pinnedTaskIds => _target.kind == IntentionKind.task
      ? (_target.taskIds.isNotEmpty ? _target.taskIds : _pinnedIds)
      : const [];

  List<String> get pinnedTaskTitles => _target.kind == IntentionKind.task
      ? (_target.taskTitles.isNotEmpty ? _target.taskTitles : _pinnedTitles)
      : const [];

  /// First pin — single-task callers (the card's deep-link, older tests).
  String? get pinnedTaskId =>
      pinnedTaskIds.isEmpty ? null : pinnedTaskIds.first;
  String? get pinnedTaskTitle =>
      pinnedTaskTitles.isEmpty ? null : pinnedTaskTitles.first;

  /// Pins finished today, intersected with the current pins so dropping a
  /// pin can never leave a phantom in the count.
  Set<String> get pinnedDoneIds => _target.kind == IntentionKind.task
      ? _pinnedDoneIds.where(pinnedTaskIds.contains).toSet()
      : const {};

  int get pinnedDoneCount => pinnedDoneIds.length;

  /// Every pinned task is finished (and there is at least one).
  bool get pinnedTaskDone =>
      pinnedTaskIds.isNotEmpty && pinnedDoneCount == pinnedTaskIds.length;

  int _progress = 0;
  bool _loading = true;

  DailyTarget get target => _target;
  int get progress => _progress;
  int get goal => _target.goal;
  bool get loading => _loading;

  double get fraction =>
      goal <= 0 ? 0 : (_progress / goal).clamp(0.0, 1.0);
  bool get met => _progress >= goal && goal > 0;
  String get dayKey => _dayKey(_now);

  /// Pure progress write. Re-picks the target when the day rolled over.
  ///
  /// Pins are optional: pass `pinnedTaskIds`/`pinnedTaskTitles` to replace
  /// the list, `pinnedDoneIds` — or the all-or-nothing `pinnedTaskDone` —
  /// to move the done set. Anything left null keeps what is in hand, so a
  /// refresh for another kind can't wipe today's pins.
  void update({
    required int contributionsToday,
    required int focusMinutesToday,
    bool? pinnedTaskDone,
    List<String>? pinnedTaskIds,
    List<String>? pinnedTaskTitles,
    Set<String>? pinnedDoneIds,
    DateTime? now,
  }) {
    if (now != null) _now = now;
    if (pinnedTaskIds != null) {
      final pair = DailyIntentionNotifier.pairPins(
          pinnedTaskIds, pinnedTaskTitles ?? _pinnedTitles);
      _pinnedIds = pair.ids;
      _pinnedTitles = pair.titles;
    } else if (pinnedTaskTitles != null) {
      _pinnedTitles =
          DailyIntentionNotifier.pairPins(_pinnedIds, pinnedTaskTitles).titles;
    }
    if (pinnedDoneIds != null) {
      _pinnedDoneIds = Set.unmodifiable(pinnedDoneIds);
    } else if (pinnedTaskDone == true) {
      _pinnedDoneIds = _pinnedIds.toSet();
    } else if (pinnedTaskDone == false) {
      _pinnedDoneIds = const {};
    }
    final fresh = _effective;
    if (fresh.title != _target.title ||
        fresh.goal != _target.goal ||
        fresh.kind != _target.kind ||
        fresh.taskId != _target.taskId) {
      _target = fresh;
      _progress = 0;
    }
    _progress = switch (_target.kind) {
      IntentionKind.tasks => contributionsToday,
      IntentionKind.focus => focusMinutesToday,
      IntentionKind.task => pinnedDoneCount,
    };
    _loading = false;
    notifyListeners();
  }

  /// Replace the pin list wholesale (order = pick order). Used by the
  /// editor's save and by a refresh that saw a pin renamed or deleted.
  void setPins({
    required List<String> ids,
    List<String>? titles,
    Set<String>? doneIds,
  }) {
    final pair =
        DailyIntentionNotifier.pairPins(ids, titles ?? const <String>[]);
    _pinnedIds = pair.ids;
    _pinnedTitles = pair.titles;
    _pinnedDoneIds = Set.unmodifiable(
        (doneIds ?? _pinnedDoneIds).where(_pinnedIds.contains));
    if (_target.kind == IntentionKind.task) {
      _target = DailyTarget(
        kind: IntentionKind.task,
        goal: _pinnedIds.isEmpty ? 1 : _pinnedIds.length,
        title: DailyIntentionNotifier.taskTitlesOf(_pinnedTitles),
        taskIds: _pinnedIds,
        taskTitles: _pinnedTitles,
      );
      // Keep today's saved target in step when a refresh — rather than
      // the editor — is what changed the pins.
      if (_custom != null && _custom!.kind == IntentionKind.task) {
        _custom = _target;
      }
      _progress = pinnedDoneCount;
    }
    notifyListeners();
  }

  /// Pin a single task. Kept for the one-task call sites.
  void pinTask({
    required String taskId,
    required String taskTitle,
    bool done = false,
  }) {
    setPins(
      ids: [taskId],
      titles: [taskTitle],
      doneIds: done ? {taskId} : const <String>{},
    );
  }

  /// Backend refresh: fetches only the signal today's target needs.
  /// Pinned targets resolve each pin to done/open + its current title.
  Future<void> refresh() async {
    try {
      if (_target.kind == IntentionKind.task) {
        final pins = pinnedTaskIds;
        final stored = pinnedTaskTitles;
        if (pins.isEmpty) {
          update(contributionsToday: 0, focusMinutesToday: 0);
          return;
        }
        final tasks = await _api.fetchTasks(withDetails: false);
        final byId = {for (final t in tasks) t.id: t};
        // An empty page is suspicious (filtered server, offline proxy):
        // hold the user's pins rather than wiping the choice.
        final holdMissing = byId.isEmpty;
        final ids = <String>[];
        final titles = <String>[];
        final doneIds = <String>{};
        for (var i = 0; i < pins.length; i++) {
          final hit = byId[pins[i]];
          if (hit == null && !holdMissing) continue; // deleted: drop it
          ids.add(pins[i]);
          titles.add(hit?.title ??
              (i < stored.length ? stored[i] : ''));
          if (hit?.status == 'done') doneIds.add(pins[i]);
        }
        setPins(ids: ids, titles: titles);
        await setPinsDone(doneIds);
        _loading = false;
        notifyListeners();
        return;
      }
      if (_target.kind == IntentionKind.tasks) {
        final heat = await _api.fetchHeatmapFull(weeks: 1);
        final today = _dayKey(DateTime.now());
        final todayCount = heat
            .where((h) =>
                _dayKey(h.date.toLocal()) == today)
            .fold<int>(0, (a, h) => a + h.count);
        update(contributionsToday: todayCount, focusMinutesToday: 0);
      } else {
        final days = await _api.fetchFocusSummary(days: 1);
        final mins =
            days.fold<int>(0, (a, d) => a + d.minutes);
        update(contributionsToday: 0, focusMinutesToday: mins);
      }
    } catch (_) {
      // Offline: hold last known progress, stop spinning.
      _loading = false;
      notifyListeners();
    }
  }

  void markOffline() {
    _loading = false;
    notifyListeners();
  }

  /// Set your own target for today (kind + goal). Beats the suggested
  /// pool pick until midnight, then the rotation resumes.
  ///
  /// For [IntentionKind.task] pass one pin (`taskId`/`taskTitle`) or many
  /// — `taskIds`/`taskTitles` in pick order. The goal becomes the number
  /// of pins, which is what the card counts towards.
  Future<void> setCustomTarget({
    required IntentionKind kind,
    required int goal,
    String? taskId,
    String? taskTitle,
    List<String>? taskIds,
    List<String>? taskTitles,
  }) async {
    final pair = DailyIntentionNotifier.pairPins(
      taskIds ?? <String>[if (taskId != null) taskId],
      taskTitles ?? <String>[if (taskTitle != null) taskTitle],
    );
    final g = kind == IntentionKind.task
        ? (pair.ids.isEmpty ? 1 : pair.ids.length)
        : clampGoal(kind, goal);
    final title = kind == IntentionKind.task
        ? DailyIntentionNotifier.taskTitlesOf(pair.titles)
        : customTitle(kind, g);
    _custom = DailyTarget(
      kind: kind,
      goal: g,
      title: title,
      taskIds: pair.ids,
      taskTitles: pair.titles,
    );
    _customDay = _dayKey(_now);
    if (kind == IntentionKind.task) {
      _pinnedIds = pair.ids;
      _pinnedTitles = pair.titles;
      _pinnedDoneIds = const {};
    }
    // Apply it right away: the sheet closes onto a card that already
    // reads "mine", without waiting for the next refresh round-trip.
    _target = _custom!;
    _progress = 0;
    _loading = false;
    // A hand-picked target supersedes any planted link (trackAsTask
    // re-stamps its own link afterwards when it is the caller).
    _trackedId = null;
    _trackedDay = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDay, _customDay!);
      await prefs.setString(_kKind, kind.name);
      await prefs.setInt(_kGoal, g);
      await prefs.setStringList(_kTaskIds, pair.ids);
      await prefs.setStringList(_kTaskTitles, pair.titles);
      await prefs.setStringList(_kTaskDoneIds, const []);
      await prefs.remove(_kTrackedId);
      await prefs.remove(_kTrackedDay);
      // Fold the single-pin era keys away for good.
      await prefs.remove(_kTaskId);
      await prefs.remove(_kTaskTitle);
      await prefs.remove(_kTaskDone);
    } catch (_) {
      // Custom target still holds in memory for this session.
    }
  }

  /// The task planted from today's target, if any (valid today only).
  String? get trackedTaskId =>
      (_trackedDay == _dayKey(_now) && _trackedId != null)
          ? _trackedId
          : null;

  /// intention→task: plant today's count/focus target as a real task on
  /// the board and pin it, closing the loop in one tap. Returns the new
  /// task, or null when there is nothing to plant (already tracked
  /// today, or the target is pins already). Throws [AuthExpiredException]
  /// and offline errors for the caller to report.
  ///
  /// [api] is a test seam; production uses the shared [_api].
  Future<Task?> trackAsTask({BloomApi? api}) async {
    if (trackedTaskId != null) return null;
    if (_target.kind == IntentionKind.task) return null;
    final t = await (api ?? _api).createTask(
      _target.title,
      tag: 'Intention',
      description: 'Tracked from ${_dayKey(_now)} intention.',
    );
    await setCustomTarget(
      kind: IntentionKind.task,
      goal: 1,
      taskIds: [t.id],
      taskTitles: [t.title],
    );
    _trackedId = t.id;
    _trackedDay = _dayKey(_now);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTrackedId, t.id);
      await prefs.setString(_kTrackedDay, _trackedDay!);
    } catch (_) {
      // Link still holds in memory for this session.
    }
    return t;
  }

  /// Drop back to the suggested rotation.
  Future<void> clearCustomTarget() async {
    _custom = null;
    _customDay = null;
    _pinnedIds = const [];
    _pinnedTitles = const [];
    _pinnedDoneIds = const {};
    _trackedId = null;
    _trackedDay = null;
    // Mirror setCustomTarget: the card flips back to the suggestion now,
    // not on the next refresh round-trip.
    _target = pickIntentionFor(_now);
    _progress = 0;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDay);
      await prefs.remove(_kKind);
      await prefs.remove(_kGoal);
      await prefs.remove(_kTaskIds);
      await prefs.remove(_kTaskTitles);
      await prefs.remove(_kTaskDoneIds);
      await prefs.remove(_kTrackedId);
      await prefs.remove(_kTrackedDay);
      await prefs.remove(_kTaskId);
      await prefs.remove(_kTaskTitle);
      await prefs.remove(_kTaskDone);
    } catch (_) {}
  }

  /// Restore yesterday's/today's override after a restart. Once per
  /// process; stale days are ignored by [_effective].
  Future<void> loadCustom() async {
    if (_customLoaded) return;
    _customLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = prefs.getString(_kDay);
      final kindStr = prefs.getString(_kKind);
      final goal = prefs.getInt(_kGoal);
      if (day == null || kindStr == null || goal == null) return;
      IntentionKind kind;
      if (kindStr == IntentionKind.focus.name) {
        kind = IntentionKind.focus;
      } else if (kindStr == IntentionKind.task.name) {
        kind = IntentionKind.task;
      } else {
        kind = IntentionKind.tasks;
      }
      final g = clampGoal(kind, goal);
      var ids = const <String>[];
      var titles = const <String>[];
      var doneIds = <String>{};
      if (kind == IntentionKind.task) {
        final storedIds = prefs.getStringList(_kTaskIds) ?? const <String>[];
        final storedTitles =
            prefs.getStringList(_kTaskTitles) ?? const <String>[];
        if (storedIds.isEmpty) {
          // Single-pin era: fold the old keys into the list form.
          final legacyId = prefs.getString(_kTaskId);
          if (legacyId != null) {
            ids = [legacyId];
            titles = [prefs.getString(_kTaskTitle) ?? ''];
            if (prefs.getBool(_kTaskDone) ?? false) doneIds = {legacyId};
          }
        } else {
          final pair = DailyIntentionNotifier.pairPins(storedIds, storedTitles);
          ids = pair.ids;
          titles = pair.titles;
          doneIds = (prefs.getStringList(_kTaskDoneIds) ?? const <String>[])
              .toSet();
        }
        _pinnedIds = ids;
        _pinnedTitles = titles;
        _pinnedDoneIds = doneIds.where(ids.contains).toSet();
      }
      _custom = DailyTarget(
        kind: kind,
        goal: kind == IntentionKind.task
            ? (ids.isEmpty ? 1 : ids.length)
            : g,
        title: kind == IntentionKind.task
            ? DailyIntentionNotifier.taskTitlesOf(titles)
            : customTitle(kind, g),
        taskIds: ids,
        taskTitles: titles,
      );
      _customDay = day;
      // Planted link survives restarts, but only for today.
      _trackedId = prefs.getString(_kTrackedId);
      _trackedDay = prefs.getString(_kTrackedDay);
      // Apply immediately when the stored day is today: otherwise _target
      // stays on the pool pick, pinnedTaskIds reads [] (getter checks
      // _target.kind), and _progress never reflects the done set.
      if (_customDay == _dayKey(_now)) {
        _target = _custom!;
        if (_target.kind == IntentionKind.task) {
          _progress = _pinnedDoneIds.length;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Replace the done set for today's pins (server truth, or a local
  /// check-off) and persist it.
  Future<void> setPinsDone(Set<String> doneIds) async {
    _pinnedDoneIds = Set.unmodifiable(doneIds.where(pinnedTaskIds.contains));
    if (_target.kind == IntentionKind.task) _progress = pinnedDoneCount;
    notifyListeners();
    await _persistPins();
  }

  /// One pin flipped — the card watches a task's live status.
  Future<void> setPinDone(String taskId, bool done) {
    final next = pinnedDoneIds.toSet();
    if (done) {
      next.add(taskId);
    } else {
      next.remove(taskId);
    }
    return setPinsDone(next);
  }

  /// Every pin at once. Kept for the single-task call sites and tests.
  Future<void> setPinnedDone(bool done) => setPinsDone(
      done ? pinnedTaskIds.toSet() : const <String>{});

  /// Write the pin lists down, folding the single-pin era keys away so a
  /// restart loads exactly one shape.
  Future<void> _persistPins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kTaskIds, _pinnedIds);
      await prefs.setStringList(_kTaskTitles, _pinnedTitles);
      await prefs.setStringList(_kTaskDoneIds, _pinnedDoneIds.toList());
      await prefs.remove(_kTaskId);
      await prefs.remove(_kTaskTitle);
      await prefs.remove(_kTaskDone);
    } catch (_) {}
  }
}
