import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/sakura_theme.dart';

/// Guided first bloom for a live-but-empty account.
///
/// A warm welcome card — not a "sample". One tap plants three real
/// starter tasks on the server; tapping any of them done runs the genuine
/// loop (heatmap +1, XP + combo). Rename or delete them afterwards; they
/// convert into the user's own data.
class FirstTaskGuide extends StatelessWidget {
  final VoidCallback onCreate;
  final bool creating;

  const FirstTaskGuide({
    super.key,
    required this.onCreate,
    this.creating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SakuraColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SakuraColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: SakuraColors.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      SakuraColors.primary,
                      SakuraColors.primary.withValues(alpha: 0.65),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.sprout,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your garden is ready',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: SakuraColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '3 tiny first blooms · 2 minutes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: SakuraColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'A quiet start beats a blank one. Plant three small wins, '
            'tap the first one done, and watch your heatmap, XP and '
            'streak wake up — then make them yours.',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: SakuraColors.inkSoft,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: SakuraColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: creating ? null : onCreate,
            icon: creating
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(LucideIcons.sprout, size: 16),
            label: Text(
              creating ? 'Planting…' : 'Plant my first blooms',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
