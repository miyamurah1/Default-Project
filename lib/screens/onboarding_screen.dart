import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';

/// First-launch onboarding — three calm slides that explain the loop
/// (plant → complete → grow). Completion persists
/// [seenKey] so it only ever shows once; auth_gate renders it before
/// AppShell on first run.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  /// SharedPreferences flag written when the user reaches the end (or
  /// taps Skip).
  static const seenKey = 'bloom_onboarding_seen_v1';

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingScreen.seenKey, true);
    } catch (_) {}
    widget.onDone();
  }

  void _next() {
    if (_page >= 2) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: AppMotion.pageTurn,
      curve: AppMotion.pageTurnCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _page >= 2;
    return Scaffold(
      backgroundColor: SakuraColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(color: SakuraColors.inkSoft),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _Slide(
                    icon: LucideIcons.flower,
                    title: 'Welcome to Daily Bloom',
                    subtitle: 'Your mindful task garden.',
                  ),
                  _Slide(
                    icon: LucideIcons.flame,
                    title: 'Complete tasks → grow your heatmap',
                    subtitle:
                        'Every finished bloom paints a square and earns XP.',
                    showHeatmap: true,
                  ),
                  _Slide(
                    icon: LucideIcons.sparkles,
                    title: 'Set intentions → build streaks → collect blooms',
                    subtitle: 'Small steps, tended daily, become a garden.',
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: AppMotion.nav,
                  curve: AppMotion.tapCurve,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? SakuraColors.primary
                        : SakuraColors.navInactive,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: Semantics(
                  button: true,
                  label: last ? 'Enter my garden' : 'Next',
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: SakuraColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _next,
                    child: Text(
                      last ? 'Enter my garden' : 'Next',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showHeatmap;

  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showHeatmap = false,
  });

  Color _heat(int i) {
    switch (i) {
      case 1:
        return SakuraColors.heat1;
      case 2:
        return SakuraColors.heat2;
      case 3:
        return SakuraColors.heat3;
      default:
        return SakuraColors.heat4;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SakuraColors.primary.withValues(alpha: 0.22),
                  SakuraColors.primary.withValues(alpha: 0.06),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: SakuraColors.primary),
          ),
          const SizedBox(height: 22),
          if (showHeatmap) ...[
            Semantics(
              label: 'Contribution heatmap preview',
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < 35; i++)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _heat(i % 5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: SakuraColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: SakuraColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
