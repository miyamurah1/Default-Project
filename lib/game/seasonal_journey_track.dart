import 'package:flutter/material.dart';

import '../theme/sakura_theme.dart';

/// One stop on the Seasonal Journey.
class SeasonMilestone {
  final String title;
  final String reward;
  const SeasonMilestone({required this.title, required this.reward});
}

/// Minimalist zen-garden timeline: muted-grey locked nodes, #FF2A55
/// completed nodes, glowing gradient connectors.
///
/// Fit-to-width Row (never scrolls): every stone stays visible, even
/// the last one on narrow phones. Nodes share space via Flexible,
/// connectors stretch via Expanded.
///
/// ```dart
/// SeasonalJourneyTrack(
///   milestones: const [
///     SeasonMilestone(title: 'First light', reward: '+50 XP'),
///     SeasonMilestone(title: 'Seven dawns', reward: '◆ 50'),
///     SeasonMilestone(title: 'Still water', reward: 'Lotus theme'),
///   ],
///   completedCount: 1,
///   onNodeTap: (i) {},
/// )
/// ```
class SeasonalJourneyTrack extends StatelessWidget {
  final List<SeasonMilestone> milestones;
  final int completedCount;
  final ValueChanged<int>? onNodeTap;

  /// Force the compact/narrow rendering instead of measuring it.
  /// Callers that already know the available width (and that need an
  /// [IntrinsicHeight]-friendly tree) pass this: a [LayoutBuilder]
  /// refuses intrinsic queries, so the wide Home row must not use one.
  final bool? compact;

  const SeasonalJourneyTrack({
    super.key,
    required this.milestones,
    required this.completedCount,
    this.onNodeTap,
    this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final forced = compact;
    if (forced != null) return _body(forced);
    return LayoutBuilder(
      builder: (context, constraints) => _body(constraints.maxWidth < 560),
    );
  }

  /// One rendering pass for a known [compact] decision. Shared by the
  /// measuring path and the forced path so both stay pixel-identical.
  Widget _body(bool compact) {
    // Wide: compact centered group with natural spacing (no dead
    // gaps). Narrow: nodes/connectors share the width so the last
    // stone never scrolls off-screen.
    final items = <Widget>[
      for (var i = 0; i < milestones.length; i++) ...[
        if (compact)
          Flexible(
            flex: 4,
            child: _Node(
              title: milestones[i].title,
              reward: milestones[i].reward,
              done: i < completedCount,
              current: i == completedCount,
              compact: true,
              onTap: onNodeTap == null
                  ? null
                  : () => onNodeTap!(i),
            ),
          )
        else
          SizedBox(
            width: 76,
            child: _Node(
              title: milestones[i].title,
              reward: milestones[i].reward,
              done: i < completedCount,
              current: i == completedCount,
              compact: false,
              onTap: onNodeTap == null
                  ? null
                  : () => onNodeTap!(i),
            ),
          ),
        if (i < milestones.length - 1)
          if (compact)
            Expanded(
              flex: 1,
              child: _Connector(
                done: i < completedCount - 1,
                compact: true,
              ),
            )
          else
            SizedBox(
              width: 44,
              child: _Connector(
                done: i < completedCount - 1,
                compact: false,
              ),
            ),
      ],
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: compact ? 104 : 116,
            child: Row(
              // Compact must fill the width so flex shares it out;
              // wide hugs its content so no dead gaps appear.
              mainAxisSize:
                  compact ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items,
            ),
          ),
        ),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool done;
  final bool compact;
  const _Connector({required this.done, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // Line sits exactly on the stones' horizontal center: node top
    // padding (8) + half the circle, minus half the 2px line.
    final d = compact ? 38.0 : 46.0;
    return Padding(
      padding:
          EdgeInsets.only(top: 8 + d / 2 - 1, left: 3, right: 3),
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: done
              ? LinearGradient(colors: [
                  SakuraColors.primary,
                  SakuraColors.primaryDark,
                ])
              : null,
          color: done ? null : SakuraColors.cardBorder,
          boxShadow: done
              ? [
                  BoxShadow(
                    color: SakuraColors.primary
                        .withValues(alpha: 0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  final String title;
  final String reward;
  final bool done;
  final bool current;
  final bool compact;
  final VoidCallback? onTap;

  const _Node({
    required this.title,
    required this.reward,
    required this.done,
    required this.current,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = compact ? 38.0 : 46.0;
    final circle = done
        ? Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: SakuraColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SakuraColors.primary
                      .withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(Icons.check,
                size: compact ? 17 : 20, color: Colors.white),
          )
        : Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: SakuraColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: current
                    ? SakuraColors.primary
                    : SakuraColors.cardBorder,
                width: current ? 2 : 1.2,
              ),
            ),
            child: Icon(
              current ? Icons.spa : Icons.lock_rounded,
              size: compact ? 15 : 17,
              color: current
                  ? SakuraColors.primary
                  : SakuraColors.inkFaint,
            ),
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            circle,
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w700,
                color: done || current
                    ? SakuraColors.ink
                    : SakuraColors.inkFaint,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reward,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: SakuraColors.inkFaint,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
