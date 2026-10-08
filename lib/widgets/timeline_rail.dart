import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/mock_data.dart' show fmtElapsed;
import '../theme/sakura_theme.dart';

/// Created -> done rail: `●──●  created Sep 29 · done Oct 1 · 2d 1h`.
///
/// One implementation for every surface (task header, Kanban cards,
/// subtask rows) so the span is always measured and worded the same
/// way: [created] -> [completed], still counting up while the work is
/// open. Renders nothing when there is no [created] stamp (offline/mock
/// rows never got one), so callers can drop it in unconditionally.
class TimelineRail extends StatelessWidget {
  /// Start node. Null hides the rail.
  final DateTime? created;

  /// End node. Null means "still running".
  final DateTime? completed;

  /// Tints the rail and fills the end node.
  final bool done;

  /// Injectable clock — tests pin it, the app leaves it null.
  final DateTime? now;

  /// Width of the line joining the two nodes.
  final double railWidth;

  final double labelSize;

  const TimelineRail({
    super.key,
    required this.created,
    this.completed,
    required this.done,
    this.now,
    this.railWidth = 20,
    this.labelSize = 10.5,
  });

  /// Wall-clock span between the nodes: completed - created, or
  /// now - created while open. Never negative.
  static Duration span({
    required DateTime created,
    DateTime? completed,
    DateTime? now,
  }) {
    final end = completed ?? now ?? DateTime.now();
    if (end.isBefore(created)) return Duration.zero;
    return end.difference(created);
  }

  /// `created Sep 29 · done Oct 1 · 2d 1h` once finished, or
  /// `created Sep 29 · running 45m` while it is still open.
  ///
  /// Stamps are drawn in local time; the API hands out UTC.
  static String label({
    required DateTime created,
    DateTime? completed,
    DateTime? now,
  }) {
    final day = DateFormat('MMM d');
    final took = fmtElapsed(
        span(created: created, completed: completed, now: now));
    final from = day.format(created.toLocal());
    if (completed == null) return 'created $from · running $took';
    return 'created $from · done ${day.format(completed.toLocal())} · $took';
  }

  @override
  Widget build(BuildContext context) {
    final start = created?.toLocal();
    if (start == null) return const SizedBox.shrink();
    final end = completed?.toLocal();
    final tint = done ? SakuraColors.primary : SakuraColors.inkFaint;
    return Row(
      children: [
        _RailDot(tint: tint, filled: true),
        SizedBox(
          width: railWidth,
          child: Center(
            child: Container(
              height: 1.5,
              color: end != null
                  ? SakuraColors.primary.withValues(alpha: 0.35)
                  : SakuraColors.cardBorder,
            ),
          ),
        ),
        _RailDot(tint: tint, filled: end != null),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label(created: start, completed: end, now: now),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: labelSize,
              color: SakuraColors.inkFaint,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// One 7px node on a [TimelineRail]: solid start, hollow until the work
/// is finished.
class _RailDot extends StatelessWidget {
  final Color tint;
  final bool filled;

  const _RailDot({required this.tint, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? tint : Colors.transparent,
        border: Border.all(color: tint, width: 1.2),
      ),
    );
  }
}
