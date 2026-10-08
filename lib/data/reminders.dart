import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
      await _plugin.initialize(settings: settings);
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
