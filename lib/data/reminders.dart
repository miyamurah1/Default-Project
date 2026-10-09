import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';

import 'mock_data.dart';

/// Payload inbox for notification taps: the background handler stashes
/// the tapped task id here (prefs — isolates can't touch widgets) and
/// AppShell drains it on launch/resume to deep-link the task.
const _kNotifTask = 'bloom_notif_task';

Future<void> _stashNotifTask(String? payload) async {
  if (payload == null || !payload.startsWith('task:')) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotifTask, payload.substring(5));
  } catch (_) {}
}

@pragma('vm:entry-point')
void onNotifTap(NotificationResponse response) {
  _stashNotifTask(response.payload);
}

@pragma('vm:entry-point')
void onNotifBackgroundTap(NotificationResponse response) {
  _stashNotifTask(response.payload);
}

/// One gentle daily nudge ("Time to tend your bloom · 9:00").
///
/// Staged, not finished: scheduling + toggle + persistence all work and
/// are unit-safe, but actual firing must be confirmed on a real device
/// (emulators lie about doze/inexact windows). Uses inexact scheduling
/// on purpose — no exact-alarm manifest permission, no Play review flag.
/// Default OFF: the app never prompts for notification permission until
/// the user flips the switch in Settings.
class ReminderService extends ChangeNotifier {
  static const _kEnabled = 'bloom_reminder_v1';
  static const _id = 1;
  static const _focusId = 2;
  static const _hour = 9;

  static final ReminderService instance = ReminderService._();
  ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _enabled = false;
  bool _ready = false;

  bool get enabled => _enabled;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(
            (await FlutterTimezone.getLocalTimezone()).identifier));
      } catch (_) {
        // Fallback keeps scheduling working with a fixed offset.
        tz.setLocalLocation(tz.getLocation('Etc/UTC'));
      }
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: onNotifTap,
        onDidReceiveBackgroundNotificationResponse: onNotifBackgroundTap,
      );
      _ready = true;
    } catch (_) {
      // Desktop / test harness: scheduling degrades to a no-op below.
      return;
    }
    // Re-arm after reboot/update: the OS drops scheduled alarms.
    if (_enabled) {
      await scheduleDaily();
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabled) ?? false;
      notifyListeners();
    } catch (_) {}
  }

  /// Flip the switch. Enabling requests OS permission first — a denial
  /// leaves the toggle off with no scheduled alarm and no nagging.
  Future<bool> setEnabled(bool value) async {
    if (value) {
      final granted = await _requestPermission();
      if (!granted) return false;
      _enabled = true;
      await _persist();
      notifyListeners();
      await scheduleDaily();
      return true;
    }
    _enabled = false;
    await _persist();
    notifyListeners();
    await cancelDaily();
    return true;
  }

  Future<bool> _requestPermission() async {
    try {
      if (kIsWeb) return true;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleDaily() async {
    if (!_ready) return;
    try {
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, _hour);
      if (!at.isAfter(now)) {
        at = at.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: _id,
        title: 'Time to tend your bloom',
        body: 'One small task today keeps the streak alive.',
        scheduledDate: at,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily-bloom',
            'Daily reminder',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  Future<void> cancelDaily() async {
    try {
      await _plugin.cancel(id: _id);
    } catch (_) {}
  }

  /// Focus-timer expiry alarm: fires once at `now + duration`, even when
  /// the app is backgrounded or the screen is locked. Exact when the OS
  /// grants it (falls back to inexact otherwise — still better than the
  /// old silent finish). Re-scheduling replaces the previous alarm, so
  /// pause/resume/±1min just call this again; abandon/finish cancels it.
  ///
  /// Permission is requested here, not at boot: starting a timer is the
  /// user's explicit consent moment. A denial degrades to in-app timing.
  Future<void> scheduleFocusTimerNotification({
    required Duration duration,
    required String label,
  }) async {
    if (!_ready) return;
    final safe = duration.isNegative ? Duration.zero : duration;
    try {
      final granted = await _requestPermission();
      if (!granted) return;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      var exact = false;
      if (android != null) {
        try {
          exact = await android.canScheduleExactNotifications() ?? false;
          if (!exact) {
            exact =
                await android.requestExactAlarmsPermission() ?? false;
          }
        } catch (_) {
          exact = false;
        }
      }
      final at = tz.TZDateTime.now(tz.local).add(safe);
      await _plugin.zonedSchedule(
        id: _focusId,
        title: '🌸 Focus session complete!',
        body:
            '“$label” — you completed your focus block. Time to take a mindful rest.',
        scheduledDate: at,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily-bloom-focus',
            'Focus timer',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  /// Drop the pending expiry alarm (pause, abandon, finish).
  Future<void> cancelFocusTimerNotification() async {
    try {
      await _plugin.cancel(id: _focusId);
    } catch (_) {}
  }

  /// Take a pending notification-tap task id left by the background
  /// handler (or null). Single-shot: the stash clears on read.
  static Future<String?> drainNotifTask() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kNotifTask);
      if (id != null) await prefs.remove(_kNotifTask);
      return (id == null || id.isEmpty) ? null : id;
    } catch (_) {
      return null;
    }
  }

  static const _kTaskAlarms = 'bloom_task_alarms_v1';

  /// Max dated tasks armed at once (OS limits + sanity).
  static const maxTaskAlarms = 50;

  /// Stable notification id per task id.
  @visibleForTesting
  static int taskAlarmId(String taskId) =>
      taskId.hashCode & 0x7fffffff;

  /// Reconcile per-task due alarms with the board: schedule future
  /// dated open tasks, cancel finished/deleted/retimed ones. Diff-only,
  /// so steady state costs zero platform calls. Past-due tasks are
  /// skipped (the plan surfaces those instead of buzzing about them).
  Future<void> syncTaskReminders(List<Task> tasks) async {
    Map<String, int> prev = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTaskAlarms);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          prev = {
            for (final e in decoded.entries)
              '${e.key}': (e.value as num?)?.toInt() ?? 0,
          };
        }
      }
    } catch (_) {}
    final now = DateTime.now();
    final want = <String, int>{};
    final wantTitles = <String, String>{};
    final open = tasks
        .where((t) =>
            t.status != 'done' &&
            t.dueAt != null &&
            t.dueAt!.isAfter(now))
        .toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    for (final t in open.take(maxTaskAlarms)) {
      want[t.id] = t.dueAt!.millisecondsSinceEpoch;
      wantTitles[t.id] = t.title;
    }
    var permissionAsked = false;
    var permitted = false;
    for (final entry in prev.entries) {
      if (want[entry.key] != entry.value) {
        try {
          await _plugin.cancel(id: taskAlarmId(entry.key));
        } catch (_) {}
      }
    }
    for (final entry in want.entries) {
      if (prev[entry.key] == entry.value) continue;
      if (!_ready) continue;
      if (!permissionAsked) {
        permissionAsked = true;
        try {
          permitted = await _requestPermission();
        } catch (_) {
          permitted = false;
        }
      }
      if (!permitted) break;
      try {
        await _scheduleTaskAlarm(
          taskId: entry.key,
          at: DateTime.fromMillisecondsSinceEpoch(entry.value),
          title: wantTitles[entry.key] ?? 'Task due',
        );
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTaskAlarms, jsonEncode(want));
    } catch (_) {}
  }

  Future<void> _scheduleTaskAlarm({
    required String taskId,
    required DateTime at,
    required String title,
  }) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    var exact = false;
    if (android != null) {
      try {
        exact = await android.canScheduleExactNotifications() ?? false;
        if (!exact) {
          exact = await android.requestExactAlarmsPermission() ?? false;
        }
      } catch (_) {
        exact = false;
      }
    }
    await _plugin.zonedSchedule(
      id: taskAlarmId(taskId),
      title: 'Due now 🌸',
      body: title,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      payload: 'task:$taskId',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily-bloom-tasks',
          'Task due dates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Drop every task alarm (account logout / wipe).
  Future<void> cancelAllTaskReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kTaskAlarms);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final k in decoded.keys) {
            try {
              await _plugin.cancel(id: taskAlarmId('$k'));
            } catch (_) {}
          }
        }
      }
      await prefs.remove(_kTaskAlarms);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, _enabled);
    } catch (_) {}
  }

  @visibleForTesting
  void debugFill({bool enabled = false}) {
    _enabled = enabled;
    notifyListeners();
  }
}
