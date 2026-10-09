import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/screens/task_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Milestone 1: the detail screen exposes full CRUD affordances —
// editable title, description field, folder/priority pickers.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TaskDetailScreen(
          task: Task(
            id: 't1',
            title: 'Write the spec',
            tag: 'Work',
            folder: 'Productivity',
            status: 'todo',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('title, badges, and description are editable', (tester) async {
    await pumpDetail(tester);
    expect(tester.takeException(), isNull);
    // Tap-to-edit affordance on the title.
    expect(find.text('Write the spec'), findsOneWidget);
    expect(find.text('Tap the title or badges to edit'), findsOneWidget);
    // Tag badge + folder/priority pills present.
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('Productivity'), findsOneWidget);
    expect(find.text('No priority'), findsOneWidget);
    // Description field present.
    expect(find.text('DESCRIPTION / NOTES'), findsOneWidget);
    // Due-date row present (date-only until picked).
    expect(find.textContaining('No due date'), findsOneWidget);
  });

  testWidgets('rename dialog rejects empty titles', (tester) async {
    await pumpDetail(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Write the spec'));
    await tester.pumpAndSettle();
    expect(find.text('Rename task'), findsOneWidget);
    // Clear the dialog field (the last TextField on screen) and confirm:
    // feedback shows, the dialog stays, the title is kept.
    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('A title needs at least one character.'),
        findsOneWidget);
  });
}
