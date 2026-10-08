// Golden (screenshot) tests for the highest-traffic UI.
//
// Goldens are platform-dependent: font rasterization differs between a
// Windows dev machine and the Linux CI runner, so these run locally and
// are skipped in CI (`CI=true`) to keep the pipeline deterministic.
//
// (Re)generate baselines after an intentional visual change:
//   flutter test --update-goldens test/golden_ui_test.dart
import 'dart:io';

import 'package:daily_bloom/data/mock_data.dart';
import 'package:daily_bloom/theme/sakura_theme.dart';
import 'package:daily_bloom/widgets/sakura_bottom_nav.dart';
import 'package:daily_bloom/widgets/task_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final skipGoldens = Platform.environment['CI'] == 'true';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SakuraTheme.useGoogleFonts = false;
    ThemeStore.instance.themeId = 'midnight';
    SakuraColors.setActive(AppThemes.midnight);
  });

  testWidgets('TaskCard — Midnight', skip: skipGoldens, (tester) async {
    const task = Task(
      id: 'g1',
      title: 'Ship the release notes',
      tag: 'Work',
      description: 'Golden snapshot of the primary task card.',
      avatarLabel: 'OP',
      comments: 2,
      priority: 'high',
    );
    await tester.pumpWidget(MaterialApp(
      theme: SakuraTheme.buildTheme(),
      home: const Scaffold(
        backgroundColor: Color(0xFF14121E),
        body: Center(
          child: SizedBox(width: 360, child: TaskCard(task: task)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card_midnight.png'),
    );
  });

  testWidgets('Bottom nav — Midnight', skip: skipGoldens, (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: SakuraTheme.buildTheme(),
      home: Scaffold(
        backgroundColor: SakuraColors.background,
        body: const SizedBox.shrink(),
        bottomNavigationBar:
            SakuraBottomNav(currentIndex: 0, onTap: (_) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(SakuraBottomNav),
      matchesGoldenFile('goldens/bottom_nav_midnight.png'),
    );
  });

  testWidgets('TaskCard — Edo (light)', skip: skipGoldens, (tester) async {
    ThemeStore.instance.themeId = 'edo';
    SakuraColors.setActive(AppThemes.sakura);
    const task = Task(
      id: 'g2',
      title: 'Morning meditation',
      tag: 'Health',
      description: 'Light-theme contrast check.',
      avatarLabel: '禅',
    );
    await tester.pumpWidget(MaterialApp(
      theme: SakuraTheme.buildTheme(),
      home: const Scaffold(
        backgroundColor: Color(0xFFFAF9F6),
        body: Center(
          child: SizedBox(width: 360, child: TaskCard(task: task)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(TaskCard),
      matchesGoldenFile('goldens/task_card_edo.png'),
    );
  });
}
