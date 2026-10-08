import 'dart:math';

import 'package:flutter/material.dart';

import '../data/haptics.dart';
import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';

/// A 300ms cherry-blossom flourish on completion.
///
/// Wraps any tappable child: on tap it fires [AppHaptics.bloom] (a short
/// double pulse) and radiates 6-8 petals outward from the child's centre,
/// then fades. Purely decorative — no layout impact, no timers, and it
/// auto-stops after one pass so an idle card costs nothing.
class PetalBurst extends StatefulWidget {
  final Widget child;

  /// Tap handler. When null the burst is decorative only (no gestures).
  final VoidCallback? onTap;

  /// Whether a tap should spawn the flourish (e.g. only when *checking*
  /// a task off, not when reopening it).
  final bool burstOnTap;

  /// Petals per flourish (clamped 6-8 for the intended "subtle" read).
  final int petalCount;

  const PetalBurst({
    super.key,
    required this.child,
    this.onTap,
    this.burstOnTap = true,
    this.petalCount = 7,
  });

  @override
  State<PetalBurst> createState() => PetalBurstState();
}

class PetalBurstState extends State<PetalBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.bounce,
  );

  /// Fire the flourish + double-pulse externally (row taps that also
  /// own the gesture).
  void burst() {
    if (!mounted) return;
    // Feedback always; the petal flourish is decorative and respects
    // reduced-motion.
    AppHaptics.bloom();
    if (!AppMotion.reduced(context)) _c.forward(from: 0);
  }

  void _handleTap() {
    if (widget.burstOnTap) burst();
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    return GestureDetector(
      onTap: interactive ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => _c.isDismissed
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        size: Size.infinite,
                        painter: _PetalFlourish(
                          progress: _c.value,
                          count: widget.petalCount.clamp(6, 8),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Radiating petals: position is a pure function of [progress], so the
/// same frame always paints the same petals (no per-frame randomness).
class _PetalFlourish extends CustomPainter {
  final double progress;
  final int count;

  const _PetalFlourish({required this.progress, required this.count});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || size.isEmpty) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final fade = (1 - progress).clamp(0.0, 1.0);
    final primary = SakuraColors.primary;
    // Deterministic angle jitter so petals don't look mechanically even.
    final rnd = Random(7);
    final reach = size.shortestSide * 0.5 + 12;

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi + rnd.nextDouble() * 0.5;
      final dist = 4 + eased * reach;
      final pos = center +
          Offset(cos(angle) * dist, sin(angle) * dist - eased * 4);
      final petalSize = 5.5 - progress * 2.5;
      final color = (i.isEven
              ? primary
              : Color.lerp(primary, Colors.white, 0.55)!)
          .withValues(alpha: fade * 0.9);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + progress * 1.2);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset.zero,
            width: petalSize * 0.72,
            height: petalSize * 1.3),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalFlourish old) =>
      old.progress != progress || old.count != count;
}
