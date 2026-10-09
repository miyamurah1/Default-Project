import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/habit_store.dart';
import '../data/haptics.dart';
import '../screens/habits_screen.dart';
import '../theme/sakura_theme.dart';
import 'bloom_sheet.dart';

/// Contextual "plant a ritual" sheet behind the Rituals-tab FAB.
///
/// Reuses the Habits screen's own editors ([showHabitSheet] /
/// [showGoalSheet]) and the built-in [RitualPresets] shelf, so a ritual
/// is only ever created one way — the FAB just shortens the path.
Future<void> showQuickAddRitual(BuildContext context) {
  return showBloomSheet<void>(
    context,
    Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Gradient header, matching the quick-add task sheet.
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    SakuraColors.primary.withValues(alpha: 0.16),
                    SakuraColors.primarySoft,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SakuraColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.sprout,
                      size: 18, color: SakuraColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Plant a ritual',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: SakuraColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AppHaptics.select();
                      Navigator.of(context).pop();
                      showHabitSheet(context);
                    },
                    icon: const Icon(LucideIcons.checkSquare, size: 16),
                    label: const Text('Habit',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SakuraColors.ink,
                      side: BorderSide(color: SakuraColors.cardBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      AppHaptics.select();
                      Navigator.of(context).pop();
                      showGoalSheet(context);
                    },
                    icon: const Icon(LucideIcons.target, size: 16),
                    label: const Text('Goal',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: SakuraColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'OR START FROM A RITUAL',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
                color: SakuraColors.inkFaint,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in RitualPresets.presets)
                  Semantics(
                    button: true,
                    label: 'Plant ${p.goalName}',
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.of(context).pop();
                        AppHaptics.tap();
                        final n = await HabitStore.instance.applyPreset(p);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(n > 0
                              ? 'Planted ${p.goalName} ($n new).'
                              : 'Already growing.'),
                        ));
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: SakuraColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: SakuraColors.cardBorder),
                        ),
                        child: Text(
                          p.goalName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: SakuraColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
  );
}
