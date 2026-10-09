import 'package:daily_bloom/data/plan_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses task + plan taps, rejects the rest', () {
    expect(
      PlanWidgetBridge.parsePlanWidgetUri(Uri.parse('dailybloom://task/abc')),
      (type: 'task', id: 'abc'),
    );
    expect(
      PlanWidgetBridge.parsePlanWidgetUri(Uri.parse('dailybloom://plan')),
      (type: 'plan', id: null),
    );
    expect(PlanWidgetBridge.parsePlanWidgetUri(Uri.parse('dailybloom://nope')), isNull);
    expect(PlanWidgetBridge.parsePlanWidgetUri(Uri.parse('https://x.test/task/a')), isNull);
    expect(PlanWidgetBridge.parsePlanWidgetUri(null), isNull);
  });

  test('push degrades to false off-device', () async {
    // Tests run on a non-mobile platform with no plugin host.
    expect(await PlanWidgetBridge.pushPlan(const []), isFalse);
    expect(await PlanWidgetBridge.initialLaunchUri(), isNull);
  });
}
