import 'package:daily_bloom/data/reminders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    ReminderService.instance.debugFill();
  });

  test('toggle persists and never throws headless', () async {
    final svc = ReminderService.instance;
    await svc.load();
    expect(svc.enabled, isFalse);
    await svc.init();
    // Headless: no permission channel, so enabling is refused and the
    // toggle honestly stays off. The allow-path needs a real device.
    expect(await svc.setEnabled(true), isFalse);
    expect(svc.enabled, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('bloom_reminder_v1') ?? false, isFalse);
    expect(await svc.setEnabled(false), isTrue);
    expect(svc.enabled, isFalse);
  });

  test('schedule/cancel are safe no-ops without a device', () async {
    final svc = ReminderService.instance;
    await svc.init();
    await svc.scheduleDaily();
    await svc.cancelDaily();
  });

  test('focus alarm schedule/cancel never throw headless', () async {
    final svc = ReminderService.instance;
    await svc.init();
    // Headless: permission request fails closed, scheduling degrades to
    // a no-op. The exact-alarm path needs a real device.
    await svc.scheduleFocusTimerNotification(
      duration: const Duration(minutes: 25),
      label: 'Free Deep Work',
    );
    await svc.cancelFocusTimerNotification();
    await svc.scheduleFocusTimerNotification(
      duration: Duration.zero,
      label: 'x',
    );
    await svc.cancelFocusTimerNotification();
  });

  test('task alarm ids are stable and non-negative', () {
    expect(ReminderService.taskAlarmId('abc'),
        ReminderService.taskAlarmId('abc'));
    expect(ReminderService.taskAlarmId('abc') >= 0, isTrue);
    expect(ReminderService.taskAlarmId('a'),
        isNot(ReminderService.taskAlarmId('b')));
  });

  test('sync + drain are headless-safe', () async {
    final svc = ReminderService.instance;
    await svc.init();
    await svc.syncTaskReminders(const []);
    await svc.cancelAllTaskReminders();
    expect(await ReminderService.drainNotifTask(), isNull);
  });
}
