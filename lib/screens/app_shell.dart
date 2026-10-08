import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/focus_controller.dart';
import '../data/task_repository.dart';
import '../game/game.dart';
import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';
import '../widgets/focus_mini_player.dart';
import '../widgets/quick_add_ritual_sheet.dart';
import '../widgets/quick_add_task_sheet.dart';
import '../widgets/sakura_bottom_nav.dart';
import '../widgets/tab_skeleton.dart';
import 'folders_screen.dart';
import 'home_screen.dart';
import 'insights_hub_screen.dart';
import 'rituals_hub_screen.dart';

/// Root shell — owns the 4-tab BottomNav, the contextual "plant" FAB and
/// the page stack.
///
/// Perf contract (mobile 60fps):
/// - Pages are created ONCE in [initState] and cached — a theme or XP
///   tick must never rebuild 4 tab states.
/// - Only the *visible* tab ticks: offscreen pages sit under
///   `TickerMode(enabled: false)` so petal loops, badge spins and glow
///   controllers pause instead of burning GPU in the background.
/// - [DynamicBloomBackground] listens to the game singleton alone; the
///   Scaffold/body does NOT rebuild on every XP tick.
/// - Tab switch is instant ([IndexedStack]) — per-page [Entrance]
///   animations carry the delight, not a full-page AnimatedSwitcher fade.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;

  /// Tabs the user has actually visited. Unvisited tabs render a
  /// lightweight placeholder so cold start only pays for Today (1 API
  /// burst instead of 4 parallel bursts on login).
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume is our "likely back online" signal: drain any mutations
    // queued while the app was backgrounded/offline.
    if (state == AppLifecycleState.resumed) {
      TaskRepository.instance.syncNow();
    }
  }

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  // Fresh (non-const) instances every build so a theme change repaints
  // every tab. State is preserved by the element tree (same types,
  // same order). A `static const` list would canonicalize the pages and
  // freeze their SakuraColors forever — that was the "theme won't apply" bug.
  //
  // Cost control: fresh widgets are cheap (configuration objects) and
  // only constructed for the *visible* tab + placeholders elsewhere;
  // the expensive work (API fetches, painters) lives in State objects
  // that Flutter preserves across these rebuilds.
  // ignore: prefer_const_constructors
  Widget _pageAt(int i) {
    if (!_visited.contains(i)) {
      // Cheap placeholder — replaced by the real tab on first visit.
      // TickerMode off: an offstage skeleton must not burn a shimmer
      // controller on cold start.
      return const TickerMode(enabled: false, child: TabSkeleton());
    }
    Widget page;
    switch (i) {
      case 0:
        // ignore: prefer_const_constructors
        page = HomeScreen(embedded: true);
        break;
      case 1:
        // Rituals = Habits + Goals hub (mirrors the Insights hub).
        // ignore: prefer_const_constructors
        page = RitualsHubScreen();
        break;
      case 2:
        // ignore: prefer_const_constructors
        page = FoldersScreen();
        break;
      default:
        // Insights = Analytics + Review + Inbox + Rules hub.
        // ignore: prefer_const_constructors
        page = InsightsHubScreen();
        break;
    }
    return TickerMode(
      enabled: i == _index,
      child: page,
    );
  }

  void _openQuickAdd() {
    showQuickAddTask(context);
  }

  void _openQuickRitual() {
    showQuickAddRitual(context);
  }

  /// Contextual "plant" action — one FAB, meaning per surface:
  /// Today + Folders plant a task; Rituals plants a ritual (habit/goal);
  /// Insights is for reflection, so it has no FAB at all.
  Widget? _fabForTab() {
    switch (_index) {
      case 3:
        return null;
      case 1:
        return FloatingActionButton(
          key: const ValueKey('fab-ritual'),
          // Distinct hero tags: two FABs coexist during the
          // AnimatedSwitcher cross-fade, so the shared default tag would
          // trip Flutter's duplicate-hero assertion on the next route push.
          heroTag: 'fab-ritual-hero',
          onPressed: _openQuickRitual,
          tooltip: 'Plant a ritual',
          backgroundColor: SakuraColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(LucideIcons.sprout, size: 24),
        );
      default:
        return FloatingActionButton(
          key: const ValueKey('fab-task'),
          heroTag: 'fab-task-hero',
          onPressed: _openQuickAdd,
          tooltip: 'Quick add task',
          backgroundColor: SakuraColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(LucideIcons.plus, size: 24),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme owns the scaffold chrome; game ticks only rebuild the
    // ambient background (streak strength), never the tab stack.
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
        final body = Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  for (var i = 0; i < SakuraBottomNav.items.length; i++)
                    _pageAt(i),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: FocusController.instance,
              builder: (context, _) => AnimatedSwitcher(
                duration: AppMotion.snackbar,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.6), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: AppMotion.settleCurve)),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: FocusMiniPlayer(
                  key: ValueKey<bool>(FocusController.instance.active),
                ),
              ),
            ),
          ],
        );
        // Hoisted OUT of the game listener: on an XP tick the builder
        // only creates a fresh DynamicBloomBackground — Scaffold and nav
        // are the same instances, so Flutter skips them entirely.
        final scaffold = Scaffold(
          backgroundColor: SakuraColors.background,
          body: body,
          // Contextual "plant" FAB: task on Today/Folders, ritual on
          // Rituals, none on Insights. Cross-fades as tabs change.
          floatingActionButton: AnimatedSwitcher(
            duration: AppMotion.nav,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _fabForTab() ??
                const SizedBox.shrink(key: ValueKey('fab-none')),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          // One stacked navbar on every width — the same
          // bottom bar phones use. No side rail on desktop.
          bottomNavigationBar: SakuraBottomNav(
            currentIndex: _index,
            onTap: _go,
          ),
        );
        return ListenableBuilder(
          listenable: GamificationStateNotifier.instance,
          builder: (context, _) => DynamicBloomBackground(
            streak: GamificationStateNotifier.instance.streak,
            child: scaffold,
          ),
        );
      },
    );
  }
}
