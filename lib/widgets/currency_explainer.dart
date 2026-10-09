import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/sakura_theme.dart';
import 'bloom_sheet.dart';

/// Currency explainer: what XP, tokens, streak, and combo actually do.
///
/// Opened by tapping the token pill in [DailyBloomAppBar]. Every number
/// below mirrors the code — [BloomEngine] for XP/combo odds, the server
/// seed (`Done → +10 tokens`, 450 start, theme prices) for tokens, and
/// the StreakTag rule (>= 3 shows) for streaks. Update this sheet when
/// the tuning changes, not the other way around.
Future<void> showCurrencyExplainer(BuildContext context) {
  return showBloomSheet(
    context,
    SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'WHAT COINS MEAN',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w600,
                color: SakuraColors.inkFaint,
              ),
            ),
            const SizedBox(height: 12),
            const _Row(
              icon: LucideIcons.star,
              title: 'XP — levels you up. ',
              body:
                  '+50 per finished task. Chain tasks within 15 minutes for a Flow Combo: the 2nd pays +60, the 3rd and beyond +100. XP fills the level bar (Lv 1–100).',
            ),
            const _Row(
              icon: LucideIcons.diamond,
              title: 'Tokens — spend in the Store. ',
              body:
                  'You start with 450. Finishing a task pays +10, habits pay about +5 (more on long streaks), and the daily bloom flower drops +10, sometimes +50, rarely +250. Themes cost 0–650; the server checks your balance.',
            ),
            const _Row(
              icon: LucideIcons.flame,
              title: 'Streak — shows at 3+ days. ',
              body:
                  'Finish something every day to grow it; skip a day and it restarts at 1. Long streaks also boost habit tokens (up to ×2.5).',
            ),
            const _Row(
              icon: LucideIcons.zap,
              title: 'Combo — finish fast, earn more. ',
              body:
                  'Tasks done within 15 minutes of each other chain into ×2, ×3… for bonus XP. It fades after 15 idle minutes.',
            ),
          ],
        ),
      ),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Row({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: SakuraColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      fontWeight: FontWeight.w700,
                      color: SakuraColors.ink,
                    ),
                  ),
                  TextSpan(
                    text: body,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: SakuraColors.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
