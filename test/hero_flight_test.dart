import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/screens/focus_timer_screen.dart';
import 'package:daily_bloom/widgets/motion.dart';
import 'package:daily_bloom/widgets/task_flow_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _task = Task(
  id: 't1',
  title: 'Write the launch notes',
  tag: 'Work',
  focusMinutes: 25,
);

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('heroPrefix threads tag to the timer chip', (tester) async {
    await tester.pumpWidget(_host(TaskFlowList(
      todo: const [_task],
      progress: const [],
      done: const [],
      onTap: (_) {},
      onOpen: (_) {},
      onToggleSub: (_, __) {},
      onTimer: (_) {},
      heroPrefix: 'home-focus-',
    )));
    await tester.pump();
    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'home-focus-t1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no prefix means no Hero (search rows unaffected)', (tester) async {
    await tester.pumpWidget(_host(TaskFlowList(
      todo: const [_task],
      progress: const [],
      done: const [],
      onTap: (_) {},
      onOpen: (_) {},
      onToggleSub: (_, __) {},
      onTimer: (_) {},
    )));
    await tester.pump();
    expect(find.byType(Hero), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip flies to the timer title without tag collision',
      (tester) async {
    // Source hero, as TaskCard would render it.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: [
              const Hero(tag: 'home-focus-t1', child: Text('00:25')),
              ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  SakuraPageRoute(
                    builder: (_) => const FocusTimerScreen(
                      task: _task,
                      heroTag: 'home-focus-t1',
                    ),
                  ),
                ),
                child: const Text('go'),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Write the launch notes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
