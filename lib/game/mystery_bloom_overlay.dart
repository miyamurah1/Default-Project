import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';
import 'bloom_engine.dart';
import 'bloom_game_colors.dart';

/// Slot-machine token ticker: rapidly scrolls upward for ~1.5s using a
/// single [AnimationController], then snaps to [target] with a soft
/// scale + glow "chime" pop (visual only — hook audio in [onDone]).
class RollingTokenCounter extends StatefulWidget {
  final int target;
  final Duration duration;
  final TextStyle? style;
  final VoidCallback? onDone;

  const RollingTokenCounter({
    super.key,
    required this.target,
    this.duration = AppMotion.counter,
    this.style,
    this.onDone,
  });

  @override
  State<RollingTokenCounter> createState() => _RollingTokenCounterState();
}

class _RollingTokenCounterState extends State<RollingTokenCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _count;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    // Ease-out cubic: fast scroll that settles gracefully, no bounce.
    _count = CurvedAnimation(parent: _c, curve: AppMotion.counterCurve);
    _c.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _popped = true);
      widget.onDone?.call();
    });
  }

  @override
  void didUpdateWidget(covariant RollingTokenCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _c.reset();
      setState(() => _popped = false);
      _c.forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _popped = true);
        widget.onDone?.call();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _count,
      builder: (context, _) {
        final shown = (widget.target * _count.value).round();
        return AnimatedScale(
          scale: _popped ? 1.1 : 1.0,
          duration: AppMotion.press,
          curve: AppMotion.pressCurve,
          // Settle back on the next frame for a soft two-step pop.
          onEnd: () {
            if (_popped && mounted) {
              Future.microtask(() {
                if (mounted) setState(() => _popped = false);
              });
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: SakuraColors.surface,
              border: Border.all(color: SakuraColors.cardBorder),
              boxShadow: [
                if (_popped)
                  BoxShadow(
                    color: SakuraColors.primary
                        .withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Text(
              '◆ $shown',
              style: (widget.style ??
                      TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: SakuraColors.ink,
                      ))
                  .copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Elegant variable-reward overlay. No loot crates — a geometric lotus
/// unfolds (staggered petals, 900ms) above a [RollingTokenCounter].
///
/// ```dart
/// final reward = game.claimDailyRitual();
/// MysteryBloomOverlay.show(context, reward: reward);
/// ```
class MysteryBloomOverlay extends StatefulWidget {
  final MysteryReward reward;
  final VoidCallback? onDismiss;

  const MysteryBloomOverlay({
    super.key,
    required this.reward,
    this.onDismiss,
  });

  /// Convenience: modal dialog with a dimmed abyss scrim.
  static Future<void> show(
    BuildContext context, {
    required MysteryReward reward,
    VoidCallback? onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Theme-aware scrim: dark veil that works on light + dark themes.
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => MysteryBloomOverlay(
        reward: reward,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<MysteryBloomOverlay> createState() => _MysteryBloomOverlayState();
}

class _MysteryBloomOverlayState extends State<MysteryBloomOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _unfold;

  @override
  void initState() {
    super.initState();
    _unfold = AnimationController(
      vsync: this,
      duration: AppMotion.burst,
    )..forward();
  }

  @override
  void dispose() {
    _unfold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reward;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: SakuraColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: SakuraColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: SakuraColors.primary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Unfolding origami lotus (custom-painted petals).
                AnimatedBuilder(
                  animation: _unfold,
                  builder: (context, _) => BloomingLotus(
                    progress: _unfold.value,
                    isCritical: r.isCritical,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  r.isCritical ? 'Critical Bloom' : 'A quiet bloom',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                    color: r.isCritical
                        ? BloomGameColors.gold
                        : SakuraColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
                RollingTokenCounter(target: r.tokens),
                const SizedBox(height: 8),
                Text(
                  '70% · 10   —   25% · 50   —   5% · 250',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: SakuraColors.inkFaint,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: SakuraColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      widget.onDismiss?.call();
                    },
                    child: const Text(
                      'Gather',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable blooming lotus: two nested rings of broad ellipse petals
/// (outer 8 + inner 8 offset by half a step, alternating lengths) that
/// unfold with a staggered overshoot, over a breathing glow with
/// slowly-orbiting sparkles and a seed pod core. Critical blooms shift
/// pink → gold. Drive [progress] 0→1 to play the unfold; the idle
/// motion loops on its own. Pass a constant 1 for a resting bloom.
class BloomingLotus extends StatefulWidget {
  final double progress;
  final bool isCritical;
  final double size;

  const BloomingLotus({
    super.key,
    required this.progress,
    this.isCritical = false,
    this.size = 148,
  });

  @override
  State<BloomingLotus> createState() => _BloomingLotusState();
}

class _BloomingLotusState extends State<BloomingLotus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    // One slow loop drives orbit + breathing — cheap, single ticker.
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  static double _easeOutBack(double p) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    final t = p - 1;
    return 1 + c3 * t * t * t + c1 * t * t;
  }

  /// One ring of petals. Each petal grows outward from the root with a
  /// per-petal stagger, alternating long/short for a natural rhythm.
  List<Widget> _ring({
    required double p,
    required int count,
    required double turn,
    required double lenScale,
    required double widScale,
    required double delay,
    required Color base,
    required Color tip,
    required double alpha,
    required double s,
  }) {
    return [
      for (var i = 0; i < count; i++)
        Builder(builder: (context) {
          final st =
              (p * 1.5 - delay - i * 0.055).clamp(0.0, 1.0);
          if (st <= 0) return const SizedBox.shrink();
          final vary = i.isEven ? 1.0 : 0.85;
          final len = s * lenScale * vary;
          final wid = s * widScale;
          final eased = _easeOutBack(st);
          return Transform.rotate(
            angle: turn + i * 2 * pi / count,
            child: Transform.translate(
              offset: Offset(0, -(s * 0.05 + len / 2)),
              child: Transform.scale(
                scale: eased,
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: (alpha * (0.35 + 0.65 * st))
                      .clamp(0.0, 1.0),
                  child: Container(
                    width: wid,
                    height: len,
                    decoration: BoxDecoration(
                      color: Color.lerp(base, tip, st),
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(wid / 2, len / 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress.clamp(0.0, 1.0);
    // Theme-matched bloom: everyday blooms grow in the theme primary
    // (blue on Ocean, green on Kyoto…); criticals keep theme roots
    // but ignite into gold at the core — rarity you can feel in any skin.
    final theme = SakuraColors.primary;
    final themeDeep = SakuraColors.primaryDark;
    const gold = BloomGameColors.gold;
    final accent = widget.isCritical ? gold : theme;
    final base = widget.isCritical ? theme : themeDeep;
    final innerTip = widget.isCritical
        ? Color.lerp(gold, const Color(0xFFFFFFFF), 0.55)!
        : Color.lerp(theme, const Color(0xFFFFFFFF), 0.55)!;
    final s = widget.size;

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _idle,
        builder: (context, _) {
          final breathe =
              0.5 + 0.5 * sin(_idle.value * 2 * pi);
          final wobble = sin(_idle.value * 2 * pi) * 0.04;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Breathing ambient glow.
              Transform.scale(
                scale: (0.72 + 0.05 * breathe) * (0.3 + 0.7 * p),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(
                        alpha: (0.10 + 0.07 * breathe) * p),
                  ),
                ),
              ),
              // Faint halo ring tracing the unfold.
              Opacity(
                opacity: 0.3 * p,
                child: Container(
                  width: s * 0.8 * (0.4 + 0.6 * p),
                  height: s * 0.8 * (0.4 + 0.6 * p),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.2),
                  ),
                ),
              ),
              // Orbiting sparkles.
              for (var i = 0; i < 8; i++)
                Positioned(
                  left: s / 2 +
                      cos(_idle.value * 2 * pi + i * pi / 4) *
                          s *
                          0.38 -
                      (i.isEven ? 2.5 : 1.5),
                  top: s / 2 +
                      sin(_idle.value * 2 * pi + i * pi / 4) *
                          s *
                          0.38 -
                      (i.isEven ? 2.5 : 1.5),
                  child: Opacity(
                    opacity: p *
                        (0.35 +
                            0.3 *
                                sin(_idle.value * 2 * pi +
                                    i * 1.3)),
                    child: Container(
                      width: i.isEven ? 5 : 3,
                      height: i.isEven ? 5 : 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i.isEven
                            ? const Color(0xFFFFFFFF)
                            : accent,
                      ),
                    ),
                  ),
                ),
              // The lotus itself, gently swaying.
              Transform.rotate(
                angle: wobble,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ..._ring(
                      p: p,
                      count: 8,
                      turn: 0,
                      lenScale: 0.40,
                      widScale: 0.20,
                      delay: 0,
                      base: base,
                      tip: accent,
                      alpha: 0.9,
                      s: s,
                    ),
                    ..._ring(
                      p: p,
                      count: 8,
                      turn: pi / 8,
                      lenScale: 0.28,
                      widScale: 0.16,
                      delay: 0.25,
                      base: accent,
                      tip: innerTip,
                      alpha: 0.95,
                      s: s,
                    ),
                    // Seed pod core.
                    Opacity(
                      opacity: p.clamp(0.0, 1.0),
                      child: Container(
                        width: s * 0.11,
                        height: s * 0.11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          border: Border.all(
                            color: const Color(0xFFFFFFFF)
                                .withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
