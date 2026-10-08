import 'package:flutter/material.dart';

import '../theme/sakura_theme.dart';

/// Cross-platform scaffold: phones get bottom tabs, wide screens get a
/// permanent rail + master-detail 2-column body.
///
/// - Mobile (width < 600): [mobileBody] full-width + [BottomNavigationBar].
/// - Desktop/tablet (>= 600): [NavigationRail] left, body is
///   master (tasks/habits, flex 5) + detail (heatmap/goals, flex 7).
///   Set [detail] null to fall back to a single full-width column.
///
/// Built only on [LayoutBuilder]/[Scaffold]/[NavigationRail] — no deps.
class ResponsiveLayoutBuilder extends StatelessWidget {
  /// Master column: task / habit lists.
  final Widget master;

  /// Pinned right column on desktop: heatmap + goals. Null = single col.
  final Widget? detail;

  /// Mobile tab bar items (BottomNavigationBar) + rail destinations.
  final List<NavigationDestination> destinations;

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Optional per-tab mobile bodies. Defaults to [master] everywhere.
  final List<Widget>? mobilePages;

  static const double breakpoint = 600;

  const ResponsiveLayoutBuilder({
    super.key,
    required this.master,
    this.detail,
    this.destinations = const [],
    this.currentIndex = 0,
    required this.onDestinationSelected,
    this.mobilePages,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) return _mobile(context);
        return _desktop(context, c);
      },
    );
  }

  // --- Mobile: full-width cards + bottom bar -----------------------------

  Widget _mobile(BuildContext context) {
    final body = mobilePages != null && mobilePages!.isNotEmpty
        ? mobilePages![currentIndex.clamp(0, mobilePages!.length - 1)]
        : master;
    return Scaffold(
      backgroundColor: SakuraColors.background,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity, // cards span 100% of phone width
          child: body,
        ),
      ),
      bottomNavigationBar: destinations.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: SakuraColors.surface,
              indicatorColor:
                  SakuraColors.primary.withValues(alpha: 0.14),
              destinations: destinations,
            ),
    );
  }

  // --- Desktop: rail + master-detail -------------------------------------

  Widget _desktop(BuildContext context, BoxConstraints c) {
    final hasDetail = detail != null;
    return Scaffold(
      backgroundColor: SakuraColors.background,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (destinations.isNotEmpty)
              NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                useIndicator: true,
                backgroundColor: SakuraColors.surface,
                indicatorColor:
                    SakuraColors.primary.withValues(alpha: 0.14),
                selectedIconTheme:
                    IconThemeData(color: SakuraColors.primary),
                unselectedIconTheme:
                    IconThemeData(color: SakuraColors.navInactive),
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                ],
              ),
            const VerticalDivider(width: 1),
            Expanded(
              flex: hasDetail ? 5 : 12,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: master,
                  ),
                ),
              ),
            ),
            if (hasDetail)
              Expanded(
                flex: 7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: detail!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
