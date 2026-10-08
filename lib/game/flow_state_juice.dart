import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';
import 'bloom_game_colors.dart';

/// Wraps a task card (or list) with calm combo feedback.
///
/// - Tap: gentle 1.02x scale bounce (implicit, no controller).
/// - Combo 1–2: soft, slowly pulsing pink ambient glow behind content.
/// - Combo 3+: glow deepens to violet + floating "+50 XP · x3" text that
///   drifts upward and fades via [SlideTransition] + [FadeTransition].
///
/// ```dart
/// FlowStateJuiceWidget(
///   comboLevel: game.comboCount,
///   onTap: () => game.registerTaskCompletion(),
///   child: TaskCard(task: task),
/// )
/// ```
class FlowStateJuiceWidget extends StatefulWidget {
  final int comboLevel;
  final Widget child;
  final VoidCallback? onTap;
  final String Function(int combo)? gainLabel;

  const FlowStateJuiceWidget({
    super.key,
    required this.comboLevel,
    required this.child,
    this.onTap,
    this.gainLabel,
  });

  @override
  State<FlowStateJuiceWidget> createState() => _FlowStateJuiceWidgetState();
}

class _FlowStateJuiceWidgetState extends State<FlowStateJuiceWidget>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _glow;
  final List<_Floater> _floaters = [];
  int _floaterSeq = 0;

  @override
  void initState() {
    super.initState();
    // One slow controller for the ambient glow — cheap, always alive,
    // drives only the glow layer (child is a static subtree).
    _glow = AnimationController(
      vsync: this,
      duration: AppMotion.glow,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect reduced-motion: hold a steady glow instead of breathing.
    if (AppMotion.reduced(context)) {
      _glow.stop();
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant FlowStateJuiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Spawn one drifting gain label when the combo climbs into 3+.
    if (widget.comboLevel > oldWidget.comboLevel && widget.comboLevel >= 3) {
      final label = widget.gainLabel != null
          ? widget.gainLabel!(widget.comboLevel)
          : '+50 XP · x${widget.comboLevel}';
      setState(() {
        _floaters.add(_Floater(id: _floaterSeq++, label: label));
        if (_floaters.length > 3) _floaters.removeAt(0);
      });
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final combo = widget.comboLevel;
    // Stable per-combo glow decoration: identical instance on every
    // animation frame, so Skia rasterizes the blur once per combo change
    // and the frame loop only re-composites the Opacity layer.
    final glowDecoration = combo >= 1
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                // Alpha-kept per BloomGameColors glow tokens: full-opacity
                // bloom/violet at 24–32px bloomed white-hot on Midnight.
                color: (combo >= 3
                        ? BloomGameColors.violet
                        : BloomGameColors.bloom)
                    .withValues(
                        alpha: combo >= 3
                            ? BloomGameColors.glowComboViolet
                            : BloomGameColors.glowComboPink),
                blurRadius: combo >= 3 ? 32 : 24,
                spreadRadius: 2,
              ),
            ],
          )
        : null;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: _down ? 1.02 : 1.0,
        duration: AppMotion.press,
        curve: AppMotion.pressCurve,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (combo >= 1)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _glow,
                  builder: (context, _) {
                    // Breathe 0.10 → 0.22 opacity; violet deepens at 3+.
                    // Stable decoration + animated Opacity only: mutating
                    // the shadow color per frame forced Skia to
                    // re-rasterize the 24–32px blur 60×/sec (combo jank).
                    return Opacity(
                      opacity: 0.10 + _glow.value * 0.12,
                      child: DecoratedBox(decoration: glowDecoration!),
                    );
                    },
                  ),
                ),
            widget.child,
            for (final f in _floaters)
              Positioned(
                top: -6,
                right: 12,
                child: _FloatingGain(
                  key: ValueKey<int>(f.id),
                  label: f.label,
                  onDone: () {
                    if (!mounted) return;
                    setState(() => _floaters.removeWhere((e) => e.id == f.id));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Floater {
  final int id;
  final String label;
  const _Floater({required this.id, required this.label});
}

/// One drifting "+XP" label: rises 36px over 1.2s while fading out,
/// then reports [onDone] so the parent can drop it.
class _FloatingGain extends StatefulWidget {
  final String label;
  final VoidCallback onDone;

  const _FloatingGain({super.key, required this.label, required this.onDone});

  @override
  State<_FloatingGain> createState() => _FloatingGainState();
}

class _FloatingGainState extends State<_FloatingGain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: AppMotion.floater,
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.4),
    ).animate(CurvedAnimation(parent: _c, curve: AppMotion.floaterCurve));
    _fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0.25, 1.0)),
    );
    _c.forward().whenComplete(() => widget.onDone());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SakuraColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: BloomGameColors.violet.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: SakuraColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
