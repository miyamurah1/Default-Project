import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';
import '../widgets/tab_skeleton.dart';
import 'goals_screen.dart';
import 'habits_screen.dart';

/// Rituals tab hub — Habits + Goals under one bottom-nav slot, mirroring
/// [InsightsHubScreen]. A compact pill row switches sections; only
/// visited sections build their (network) children, so cold start pays
/// for the Habits list alone.
class RitualsHubScreen extends StatefulWidget {
  const RitualsHubScreen({super.key});

  @override
  State<RitualsHubScreen> createState() => _RitualsHubScreenState();
}

class _RitualsHubScreenState extends State<RitualsHubScreen> {
  static const _labels = ['Habits', 'Goals'];
  static const _icons = [LucideIcons.sprout, LucideIcons.target];

  int _index = 0;
  final Set<int> _visited = {0};

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  Widget _pageAt(int i) {
    if (!_visited.contains(i)) {
      // Offstage skeleton placeholder (shimmer paused offscreen).
      return const TickerMode(enabled: false, child: TabSkeleton());
    }
    Widget page;
    switch (i) {
      case 0:
        page = const HabitsScreen();
        break;
      default:
        page = const GoalsScreen(embedded: true);
        break;
    }
    return TickerMode(enabled: i == _index, child: page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakuraColors.background,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++)
                    Expanded(
                      child: _SegmentButton(
                        label: _labels[i],
                        icon: _icons[i],
                        active: i == _index,
                        onTap: () => _go(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _labels.length; i++) _pageAt(i),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: AnimatedContainer(
          duration: AppMotion.nav,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: active
                ? SakuraColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      active ? SakuraColors.navActive : SakuraColors.navInactive,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.2,
                  color: active
                      ? SakuraColors.navActive
                      : SakuraColors.navInactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
