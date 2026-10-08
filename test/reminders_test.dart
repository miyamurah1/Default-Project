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
}
