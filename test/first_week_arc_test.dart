import 'package:daily_bloom/game/first_week_arc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// First-week arc: a fresh install sees plant → plan → stake in order,
// and never again once complete.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FirstWeekArc.instance.debugReset();
    await FirstWeekArc.instance.load();
  });

  tearDown(() => FirstWeekArc.instance.debugReset());

  test('arc starts at planting and finishes after all three', () async {
    expect(FirstWeekArc.instance.nextStep, 0);
    expect(FirstWeekArc.instance.prompt, contains('3'));

    await FirstWeekArc.instance.report(FirstWeekStep.planted);
    expect(FirstWeekArc.instance.nextStep, 1);
    expect(FirstWeekArc.instance.prompt, contains('Plan my day'));

    await FirstWeekArc.instance.report(FirstWeekStep.planned);
    expect(FirstWeekArc.instance.nextStep, 2);
    expect(FirstWeekArc.instance.prompt, contains('Stake'));

    await FirstWeekArc.instance.report(FirstWeekStep.staked);
    expect(FirstWeekArc.instance.isComplete, isTrue);
    expect(FirstWeekArc.instance.nextStep, isNull);
    expect(FirstWeekArc.instance.prompt, isEmpty);
  });

  test('arc state survives a reload', () async {
    await FirstWeekArc.instance.report(FirstWeekStep.planned);
    FirstWeekArc.instance.debugReset();
    await FirstWeekArc.instance.load();
    expect(FirstWeekArc.instance.planned, isTrue);
    expect(FirstWeekArc.instance.nextStep, 0);
  });
}
