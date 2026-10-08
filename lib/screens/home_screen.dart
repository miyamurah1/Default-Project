import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import '../data/auth_store.dart';
import '../data/energy_store.dart';
import '../data/mock_data.dart';
import '../data/task_repository.dart';
import '../game/game.dart';
import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';
import '../widgets/concept_map_card.dart';
import '../widgets/contribution_heatmap.dart';
import '../widgets/daily_bloom_app_bar.dart';
import '../widgets/daily_intention_card.dart';
import '../widgets/first_task_guide.dart';
import '../widgets/level_up_burst.dart';
import '../widgets/motion.dart';
import '../widgets/task_flow_list.dart';
import 'focus_timer_screen.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'matrix_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'store_screen.dart';
import 'task_detail_screen.dart';

/// Home tab — clean, performant routing hub.
///
/// Data layer (Postgres via [BloomApi] with mock fallback) lives here;
/// all section UI is delegated to modular widgets. Top-to-bottom order:
///
/// - Bento header — [DailyIntentionCard] (compact) + [_GameHud]
///   (seedling rank / XP / streak) in one ~130px band.
/// - [ContributionHeatmap] — 12-week GitHub-style grid: the day's
///   evidence, sitting directly under the header.
/// - [_QuickLinks] — Board matrix / History / Insights / Review doors.
/// - [TaskFlowList] — Kanban board (`widgets/task_flow_list.dart`),
///   intentionally last: the work sits below the proof and the doors.
///
/// Habit tracking lives only in the dedicated Habits tab
/// (`HabitsScreen`) — Home intentionally shows no habit UI.
///
/// Responsive contract (breakpoint 600):
/// - Mobile (< 600): one unified [CustomScrollView] ([SliverList] +
///   [SliverToBoxAdapter]) + [BottomNavigationBar] section nav.
/// - Desktop (>= 600): same stacked flow, full viewport width.
///   One column everywhere means no side column can ever sit empty
///   beside a longer one — the page simply ends after the last card.
/// App-level tab routing stays in AppShell and is the app's ONLY nav
/// system (the old desktop rail was removed). The inner section bar here
/// exists solely for the standalone/test configuration; pass [embedded]
/// when hosted inside AppShell so it hides and never doubles the outer
/// bottom nav.
class HomeScreen extends StatefulWidget {
  /// True when hosted inside AppShell's tab stack.
  final bool embedded;

  const HomeScreen({super.key, this.embedded = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _breakpoint = 600;

  final _api = BloomApi();

  List<Task> _todo = const [];
  List<Task> _prog = const [];
  List<Task> _done = const [];
  List<HeatDay> _heat = [];
  bool _live = false;
  String? _note;
  int _bestStreak = 0;

  /// First-run helpers: the dismissible concept map (persisted) and the
  /// guided sample-task button (live + empty account only).
  static const _kConceptSeen = 'bloom_concept_seen_v1';
  bool _conceptVisible = true;
  bool _creatingSample = false;

  /// In-home section nav (Intention / Flow).
  int _sectionIndex = 0;
  final ScrollController _mobileScroll = ScrollController();
  final _intentionKey = GlobalKey();
  final _flowKey = GlobalKey();

  /// Honest offline grid: 12 weeks of quiet days. Never anyone else's
  /// activity — the live heatmap replaces this on a successful sync.
  List<HeatDay> _zeroHeat({int weeks = 12}) {
    final today = DateTime.now();
    final total = weeks * 7;
    return List<HeatDay>.generate(
      total,
      (i) => HeatDay(
        date: today.subtract(Duration(days: total - 1 - i)),
        count: 0,
        level: 0,
      ),
    );
  }

  String get _streakLabel =>
      _live && _bestStreak > 0 ? 'Best streak: $_bestStreak days' : 'Best streak: —';

  @override
  void initState() {
    super.initState();
    _heat = _zeroHeat();
    _loadConcept();
    // Offline-first: Home renders the repository's cached tasks and
    // repaints whenever it changes, so a failed sync never blanks the
    // screen. The repo owns optimistic edits + local persistence.
    TaskRepository.instance.addListener(_onRepoChanged);
    TaskRepository.instance.init();
    _refresh();
  }

  /// Repository -> local lists. Fires on cache load, remote sync and
  /// every optimistic create/move/delete, keeping the board live even
  /// while offline.
  void _onRepoChanged() {
    if (!mounted) return;
    setState(() {
      _todo = TaskRepository.instance.todoTasks;
      _prog = TaskRepository.instance.inProgressTasks;
      _done = TaskRepository.instance.doneTasks;
    });
  }

  /// The concept map shows until dismissed once (persisted). Offline test
  /// pumps with empty prefs, so it is visible there too — by design.
  Future<void> _loadConcept() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _conceptVisible = !(prefs.getBool(_kConceptSeen) ?? false);
      });
    } catch (_) {}
  }

  Future<void> _dismissConcept() async {
    setState(() => _conceptVisible = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kConceptSeen, true);
    } catch (_) {}
  }

  /// True for a live-but-empty account: the guided sample's moment.
  /// Offline stays honestly empty (Phase 1 trust rule).
  bool get _showGuide =>
      _live &&
      _todo.isEmpty &&
      _prog.isEmpty &&
      _done.isEmpty;

  /// Plants three REAL starter tasks — a warm welcome, not a "sample".
  /// Toggling any of them done runs the genuine loop (heatmap +1, XP +
  /// combo); the user renames or deletes them afterwards — they convert
  /// into their own data.
  Future<void> _createSample() async {
    if (_creatingSample || !_live) return;
    setState(() => _creatingSample = true);
    try {
      for (final s in starterTasks) {
        await _api.createTask(
          s.title,
          tag: s.tag,
          description: s.description,
        );
      }
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Welcome blooms planted — tap the first one done. 🌸')),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e is AuthExpiredException) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not plant — try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingSample = false);
    }
  }

  @override
  void dispose() {
    TaskRepository.instance.removeListener(_onRepoChanged);
    _mobileScroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _api.fetchHeatmapFull(weeks: 12),
        _api.fetchProgress(),
        _api.fetchWallet(),
      ]);
      if (!mounted) return;
      final progress = results[1] as Map<String, int>;
      setState(() {
        _heat = (results[0] as List<HeatDay>);
        _bestStreak = progress['bestStreak'] ?? 0;
        _live = true;
        _note = null;
      });
      // Pull the authoritative list; the repository notifies and the
      // board repaints from cache + remote through one path.
      await TaskRepository.instance.loadRemote(withDetails: true);
      await EnergyStore.instance
          .prune(TaskRepository.instance.tasks.map((t) => t.id));
      await _syncIntention();
    } catch (e) {
      if (!mounted) return;
      // Expired session: AuthStore already bounced to login via AuthGate.
      if (e is AuthExpiredException) return;
      // Offline: never wipe. The repository keeps whatever it cached so
      // tasks stay visible and editable until the next successful sync.
      setState(() {
        _todo = TaskRepository.instance.todoTasks;
        _prog = TaskRepository.instance.inProgressTasks;
        _done = TaskRepository.instance.doneTasks;
        if (_heat.isEmpty) _heat = _zeroHeat();
        _live = false;
        _note = 'API offline — showing your saved tasks.';
      });
      DailyIntentionNotifier.instance.markOffline();
    }
  }

  Future<void> _complete(Task t) async {
    // Local game juice first — works offline so combo is always visible.
    final game = GamificationStateNotifier.instance;
    final levelBefore = game.level;
    game.registerTaskCompletion();
    // Level crossing → one-shot burst + fanfare (no dialog stacks).
    if (game.level > levelBefore && mounted) {
      LevelUpBurst.celebrate(context, game);
    }
    final next = nextStatus(t);
    // Repository move is optimistic + persisted: the board updates at
    // 0ms and survives offline. No "start the backend" dead-end.
    await TaskRepository.instance.moveTask(t.id, next);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(next == 'done'
                ? 'Done — heatmap +1 (like git commit).'
                : 'Back in progress — finish it.')),
      );
    }
    // Analytics catch up only when the backend is reachable.
    if (_live) await _refresh();
  }

  void _openDetail(Task t) {
    Navigator.of(context)
        .push(SakuraPageRoute(builder: (_) => TaskDetailScreen(task: t)))
        .then((_) => _refresh()); // counts may have changed inside
  }

  void _toggleSub(Subtask s, bool done) async {
    // Routed through the repository: optimistic locally and queued in
    // the offline outbox when the backend is unreachable. TaskCard owns
    // the petal burst + UNDO snackbar.
    await TaskRepository.instance.setSubtaskDone(s.id, done);
  }

  void _openTimer(Task t) {
    Navigator.of(context)
        .push(SakuraPageRoute(
            builder: (_) =>
                FocusTimerScreen(task: t, heroTag: 'home-focus-${t.id}')))
        .then((_) => _refresh()); // focus time may have grown
  }

  Future<void> _syncIntention() async {
    final game = DailyIntentionNotifier.instance;
    if (!_live) {
      game.markOffline();
      return;
    }
    // Tasks signal reuses the heatmap already in hand — zero extra IO.
    if (game.target.kind == IntentionKind.tasks) {
      game.update(
        contributionsToday: heatCountFor(_heat, DateTime.now()),
        focusMinutesToday: 0,
      );
      return;
    }
    try {
      final days = await _api.fetchFocusSummary(days: 1);
      if (!mounted) return;
      game.update(
        contributionsToday: 0,
        focusMinutesToday: days.fold<int>(0, (a, d) => a + d.minutes),
      );
    } catch (_) {
      game.markOffline();
    }
  }

  void _claimBloom() {
    // Gather thump: the reward moment gets the heavier buzz.
    HapticFeedback.mediumImpact();
    final reward = GamificationStateNotifier.instance.claimDailyRitual();
    MysteryBloomOverlay.show(context, reward: reward);
  }

  void _jumpToSection(int index) {
    setState(() => _sectionIndex = index);
    final keys = [_intentionKey, _flowKey];
    final ctx = keys[index.clamp(0, keys.length - 1)].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: AppMotion.scroll,
        curve: AppMotion.scrollCurve,
      );
    }
  }

  /// In-home section [BottomNavigationBar] (standalone only).
  BottomNavigationBar _sectionBar() {
    return BottomNavigationBar(
      currentIndex: _sectionIndex,
      onTap: _jumpToSection,
      type: BottomNavigationBarType.fixed,
      backgroundColor: SakuraColors.surface,
      selectedItemColor: SakuraColors.primary,
      unselectedItemColor: SakuraColors.navInactive,
      selectedFontSize: 10,
      unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.sun), label: 'Intention'),
        BottomNavigationBarItem(
            icon: Icon(LucideIcons.listChecks), label: 'Flow'),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Routing hub: watches game + theme, then branches on width.
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Theme-only listener at the root. Game/XP ticks used to live here
    // too — which rebuilt the heatmap, HUD, quick links AND the whole
    // 30-card board on every XP gain. Streak/tokens now read inside
    // _GameHud (listens itself) and the app bar's token pill (listens
    // itself), so an XP tick repaints those two small subtrees only.
    return ListenableBuilder(
      listenable: ThemeStore.instance,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < _breakpoint;
            // Serene dark baseline (#120D1C) resolves through the active
            // Sakura theme — midnight paints near-identical.
            return Scaffold(
              backgroundColor:
                  Theme.of(context).scaffoldBackgroundColor,
              appBar: DailyBloomAppBar(
                onStoreTap: () {
                  Navigator.of(context).push(
                    SakuraPageRoute(
                        builder: (_) => const StoreScreen()),
                  );
                },
                onLogoutTap: () async {
                  ThemeStore.instance.resetToDefault();
                  await AuthStore.instance.logout();
                  // No navigation needed: AuthGate swaps to LoginScreen and
                  // the old AppShell tree is discarded (no back-button leak).
                },
                onSettingsTap: () {
                  Navigator.of(context).push(
                    SakuraPageRoute(
                        builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              body: isMobile ? _mobileBody() : _desktopBody(),
              // One stacked section bar on every width when
              // standalone — AppShell already owns the outer app
              // nav and must stay the single bottom bar.
              bottomNavigationBar:
                  !widget.embedded ? _sectionBar() : null,
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Mobile (< 600): one unified CustomScrollView.
  // ------------------------------------------------------------------

  /// Compact Zen Bento header (~130px): today's intention beside the
  /// seedling (rank + XP + streak). Consolidates the three former stacked
  /// cards into one glance, freeing vertical room so "Today's Flow" lands
  /// in the primary viewport on phones.
  Widget _bentoHeader() {
    return SizedBox(
      key: const ValueKey('home_hud_card'),
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            // 5:4 (was 3:2): the seedling cell needs ~140px on a 360px
            // phone for rank/streak text beside the badge — at 3:2 its
            // text column collapsed to ~48px and ellipsised every rank.
            flex: 5,
            child: DailyIntentionCard(
              compact: true,
              onTargetMet: _claimBloom,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: _GameHud(onBloom: _claimBloom),
          ),
        ],
      ),
    );
  }

  Widget _mobileBody() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: SakuraColors.primary,
      backgroundColor: SakuraColors.surface,
      strokeWidth: 2.5,
      child: CustomScrollView(
        controller: _mobileScroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _SyncBanner(live: _live, note: _note)),
          if (_conceptVisible)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: ConceptMapCard(onDismiss: _dismissConcept),
              ),
            ),
          // Zen Bento header: intention + seedling + streak in one compact
          // band, right under the bar.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Container(key: _intentionKey, child: _bentoHeader()),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Evidence sits above the work: the heat map reads as what the
          // committed tasks grew into.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ContributionHeatmap(
                days: _heat,
                bestStreakLabel: _streakLabel,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Doors to review (Board / History / Insights / Review).
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                key: ValueKey('home_quick_link_$i'),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _QuickLinks.rowItem(i, context),
              ),
              childCount: 4,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Today's Flow last: the board is the day's work, reached after
          // the header, evidence and doors above it.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                key: _flowKey,
                child: TaskFlowList(
                  todo: _todo,
                  progress: _prog,
                  done: _done,
                  onTap: _complete,
                  onOpen: _openDetail,
                  onToggleSub: _toggleSub,
                  onTimer: _openTimer,
                  heroPrefix: 'home-focus-',
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (_showGuide)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: FirstTaskGuide(
                  onCreate: _createSample,
                  creating: _creatingSample,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Desktop (>= 600): unified scroll behind the equal HUD row.
  // ------------------------------------------------------------------

  Widget _desktopBody() {
    // No side rail: desktop stacks the same bottom section bar
    // as mobile (bottomNavigationBar). One navbar everywhere.
    return RefreshIndicator(
      onRefresh: _refresh,
      color: SakuraColors.primary,
      backgroundColor: SakuraColors.surface,
      strokeWidth: 2.5,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SyncBanner(live: _live, note: _note),
            if (_conceptVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: ConceptMapCard(onDismiss: _dismissConcept),
              ),
            // Zen Bento header spans the full content width.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Container(key: _intentionKey, child: _bentoHeader()),
            ),
            const SizedBox(height: 12),
            // Evidence above the work — same order as mobile.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ContributionHeatmap(
                days: _heat,
                bestStreakLabel: _streakLabel,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _QuickLinks(key: ValueKey('home_quick_links')),
            ),
            const SizedBox(height: 12),
            // Today's Flow last.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                key: _flowKey,
                child: TaskFlowList(
                  todo: _todo,
                  progress: _prog,
                  done: _done,
                  onTap: _complete,
                  onOpen: _openDetail,
                  onToggleSub: _toggleSub,
                  onTimer: _openTimer,
                  heroPrefix: 'home-focus-',
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_showGuide)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: FirstTaskGuide(
                  onCreate: _createSample,
                  creating: _creatingSample,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Live/offline sync pill + offline note. Pure presentational extract.
class _SyncBanner extends StatelessWidget {
  final bool live;
  final String? note;

  const _SyncBanner({required this.live, this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                // Theme-native states: tinted brand when live, quiet
                // surface when offline — no pastel hardcodes glowing in
                // Midnight. Matches the app-bar pill language.
                color: live ? SakuraColors.primarySoft : SakuraColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SakuraColors.cardBorder),
              ),
              child: Text(
                live ? '● live db' : '○ offline',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: live ? SakuraColors.primary : SakuraColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 20, right: 20),
            child: Text(note!,
                style:
                    TextStyle(fontSize: 11, color: SakuraColors.inkSoft)),
          ),
      ],
    );
  }
}

/// Board / History / Insights / Review shortcuts. Extracted so both
/// layouts share it.
/// Rendered directly under the seedling (rank badge + XP bar): growth
/// first, then the doors that let you review it.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks({super.key});

  /// Single row item for the mobile [SliverList].
  static Widget rowItem(int index, BuildContext context) {
    // One style for all four: all caps, single trailing arrow.
    switch (index) {
      case 0:
        return _link(context, 'BOARD →', () {
          Navigator.of(context).push(
            SakuraPageRoute(builder: (_) => const MatrixScreen()),
          );
        });
      case 1:
        return _link(context, 'HISTORY →', () {
          Navigator.of(context).push(
            SakuraPageRoute(builder: (_) => const HistoryScreen()),
          );
        });
      case 2:
        return _link(context, 'VIEW INSIGHTS →', () {
          Navigator.of(context).push(
            SakuraPageRoute(builder: (_) => const InsightsScreen()),
          );
        });
      default:
        return _link(context, 'REVIEW →', () {
          Navigator.of(context).push(
            SakuraPageRoute(builder: (_) => const ReviewScreen()),
          );
        });
    }
  }

  static Widget _link(
      BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: SakuraColors.primary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap (not spaceBetween Row): the master column is narrow on
    // desktop and phones are narrower still — never overflow.
    return Wrap(
      spacing: 20,
      runSpacing: 4,
      alignment: WrapAlignment.spaceBetween,
      children: [
        rowItem(0, context),
        rowItem(1, context),
        rowItem(2, context),
        rowItem(3, context),
      ],
    );
  }
}

/// Compact progression header: rank badge + XP bar + combo / tokens.
/// Listens to the game singleton itself so an XP/tick update rebuilds
/// this card only — Home's root builder no longer subscribes to game
/// state (that rebuilt the heatmap + board on every XP gain).
class _GameHud extends StatelessWidget {
  final VoidCallback onBloom;

  const _GameHud({
    required this.onBloom,
  });

  @override
  Widget build(BuildContext context) {
    // Merge game + theme: the card repaints on XP changes AND theme swaps,
    // so it can never go stale (white-on-dark) after equipping a theme.
    return ListenableBuilder(
      listenable: Listenable.merge([
        GamificationStateNotifier.instance,
        ThemeStore.instance,
      ]),
      builder: (context, _) {
        final game = GamificationStateNotifier.instance;
        // Compact bento cell: rank + level + streak/combo + XP bar + a
        // small bloom button. Sized to live beside the intention cell in
        // the ~130px header.
        return Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          decoration: SakuraTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  BloomRankBadge(level: game.level, size: 42, showLabel: false),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Rank name only — the level digit already lives
                        // in the badge core and the cell is too narrow
                        // for 'Name · Lv N' on phones. FittedBox shrinks
                        // the longest rank ('Sakura Bloom') instead of
                        // ellipsising it.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            game.rankName,
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: SakuraColors.ink),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(LucideIcons.flame,
                                size: 11, color: SakuraColors.primary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${game.streak}d · x${game.comboCount}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: SakuraColors.inkSoft,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: game.levelProgress,
                  minHeight: 6,
                  backgroundColor: SakuraColors.primarySoft,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(SakuraColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: AnimatedInt(
                      value: game.xpIntoLevel,
                      formatter: (v) => '$v/${game.xpNeeded} XP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: SakuraColors.inkSoft,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onBloom,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: SakuraColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.flower,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}