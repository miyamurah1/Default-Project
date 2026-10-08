import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/api_client.dart';
import '../data/auth_store.dart';
import '../theme/sakura_theme.dart';
import '../widgets/motion.dart';
import 'insights_screen.dart';

/// Goals tab — live weekly numbers: focus minutes, completion,
/// streak, and strongest tags. Falls back to zeros offline.
class GoalsScreen extends StatefulWidget {
  final bool embedded;
  const GoalsScreen({super.key, this.embedded = false});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _api = BloomApi();

  int _focusMin = 0;
  int _done = 0;
  int _total = 0;
  int _streak = 0;
  List<SplitStat> _tags = [];
  List<FocusDay> _week = [];
  List<String> _tips = [];
  bool _loading = true;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.fetchProgress(),
        _api.fetchFocusSummary(days: 7),
        _api.fetchInsights(),
      ]);
      if (!mounted) return;
      final progress = results[0] as Map<String, int>;
      final days = results[1] as List<FocusDay>;
      final week =
          days.fold<int>(0, (a, d) => a + d.minutes);
      final ins = results[2] as Insights;
      final done = progress['done'] ?? 0;
      final total = (progress['todo'] ?? 0) +
          (progress['in_progress'] ?? 0) +
          done;
      setState(() {
        _focusMin = week;
        _done = done;
        _total = total;
        _streak = progress['currentStreak'] ?? 0;
        _tags = ins.byTag.take(3).toList();
        _week = days.length <= 7 ? days : days.sublist(days.length - 7);
        _tips = buildInsights(ins).take(3).toList();
        _loading = false;
        _live = true;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is AuthExpiredException) return;
      setState(() => _loading = false);
    }
  }

  String _weekLabel() {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final mon = now.subtract(Duration(days: now.weekday - 1));
    final sun = mon.add(const Duration(days: 6));
    return '${months[mon.month - 1]} ${mon.day} – ${months[sun.month - 1]} ${sun.day}';
  }

  @override
  Widget build(BuildContext context) {
    final rate = _total == 0 ? 0.0 : _done / _total;
    final content = RefreshIndicator(
      color: SakuraColors.primary,
      backgroundColor: SakuraColors.surface,
      onRefresh: _load,
      child: LayoutBuilder(
            builder: (context, constraints) {
              // Three tiers: phones stack; desktop gets a dashboard row;
              // ultrawide gets a two-column magazine spread capped at
              // 1080px, so the page always fills its canvas on purpose.
              final wide = constraints.maxWidth >= 820;
              final xwide = constraints.maxWidth >= 1100;
              return ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth:
                              xwide ? 1080 : wide ? 880 : 720),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          const SizedBox(height: 18),
                          if (_loading)
                            const Center(
                                child: Padding(
                              padding: EdgeInsets.all(24),
                              child:
                                  CircularProgressIndicator(),
                            ))
                          else if (xwide) ...[
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Entrance(
                                        delayMs: 0,
                                        child: _hero(rate),
                                      ),
                                      const SizedBox(height: 16),
                                      Entrance(
                                        delayMs: 120,
                                        child: _tileGrid(rate,
                                            wide: false),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Entrance(
                                        delayMs: 120,
                                        child: _tagsCard(),
                                      ),
                                      const SizedBox(height: 16),
                                      Entrance(
                                        delayMs: 220,
                                        child: _insightCard(),
                                      ),
                                      const SizedBox(height: 16),
                                      Entrance(
                                        delayMs: 300,
                                        child: _peakCard(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Entrance(
                              delayMs: 300,
                              child: _weekCard(),
                            ),
                          ] else if (wide) ...[
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                Expanded(
                                  flex: 5,
                                  child: Entrance(
                                    delayMs: 0,
                                    child: _hero(rate),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 6,
                                  child: Entrance(
                                    delayMs: 120,
                                    child: _tagsCard(),
                                  ),
                                ),
                              ],
                            ),
                            ),
                            const SizedBox(height: 16),
                            Entrance(
                              delayMs: 220,
                              child: _tileGrid(rate, wide: true),
                            ),
                            const SizedBox(height: 16),
                            Entrance(
                              delayMs: 300,
                              child: _weekCard(),
                            ),
                            const SizedBox(height: 16),
                            Entrance(
                              delayMs: 380,
                              child: _insightCard(),
                            ),
                          ] else ...[
                            Entrance(
                              delayMs: 0,
                              child: _hero(rate),
                            ),
                            const SizedBox(height: 14),
                            Entrance(
                              delayMs: 120,
                              child: _tileGrid(rate, wide: false),
                            ),
                            const SizedBox(height: 14),
                            Entrance(
                              delayMs: 220,
                              child: _tagsCard(),
                            ),
                            const SizedBox(height: 14),
                            Entrance(
                              delayMs: 300,
                              child: _weekCard(),
                            ),
                            const SizedBox(height: 14),
                            Entrance(
                              delayMs: 380,
                              child: _insightCard(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: SakuraColors.background,
      body: SafeArea(
        bottom: false,
        child: content,
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目標',
          style: SakuraTheme.display(
            fontSize: 30,
            height: 1.0,
            fontWeight: FontWeight.w800,
            color: SakuraColors.primary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              'GOALS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 3.2,
                fontWeight: FontWeight.w600,
                color: SakuraColors.inkFaint,
              ),
            ),
            const Spacer(),
            if (!_live && !_loading)
              Text(
                '○ offline',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: SakuraColors.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _hero(double rate) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: SakuraColors.primary,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color:
                SakuraColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK · ${_weekLabel().toUpperCase()}',
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_focusMin min focused',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Text('Completion',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12)),
              Text('${(100 * rate).round()}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [
                        FontFeature.tabularFigures()
                      ])),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                      Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileGrid(double rate, {required bool wide}) {
    final tiles = [
      _StatCard(
          icon: LucideIcons.timer,
          label: 'FOCUS MINS',
          value: '$_focusMin'),
      _StatCard(
          icon: LucideIcons.check,
          label: 'TASKS DONE',
          value: '$_done'),
      _StatCard(
          icon: LucideIcons.percent,
          label: 'COMPLETION',
          value: '${(100 * rate).round()}%'),
      _StatCard(
          icon: LucideIcons.flame,
          label: 'DAY STREAK',
          value: _streak > 0 ? '${_streak}d' : '—'),
    ];
    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: tiles[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 14),
          Expanded(child: tiles[1]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: 14),
          Expanded(child: tiles[3]),
        ]),
      ],
    );
  }

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// True calendar week (Mon–Sun) with zero-filled days, so the chart
  /// always reads as a week — never 3 lopsided slabs. Future days render
  /// as quiet tracks; today is solid primary.
  Widget _weekCard() {
    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final mon = now.subtract(Duration(days: now.weekday - 1));
    final weekDays =
        List.generate(7, (i) => mon.add(Duration(days: i)));
    final byDay = <String, int>{};
    for (final d in _week) {
      final parsed = DateTime.tryParse(d.date);
      if (parsed != null) {
        byDay[_dayKey(parsed)] =
            (byDay[_dayKey(parsed)] ?? 0) + d.minutes;
      }
    }
    final minutes =
        weekDays.map((d) => byDay[_dayKey(d)] ?? 0).toList();
    final max = minutes.fold<int>(
        0, (a, m) => m > a ? m : a);
    final total = minutes.fold<int>(0, (a, m) => a + m);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SakuraTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'FOCUS THIS WEEK',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w600,
                    color: SakuraColors.inkFaint,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$total min total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SakuraColors.inkSoft,
                  fontFeatures: const [
                    FontFeature.tabularFigures()
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_live)
            Text(
              'Offline — connect to load.',
              style: TextStyle(color: SakuraColors.inkSoft),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _weekBar(
                      minutes: minutes[i],
                      max: max,
                      letter: _dayLetters[i],
                      isToday:
                          _dayKey(weekDays[i]) == todayKey,
                      isFuture: weekDays[i]
                          .isAfter(DateTime(
                              now.year, now.month, now.day)),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _weekBar({
    required int minutes,
    required int max,
    required String letter,
    required bool isToday,
    required bool isFuture,
  }) {
    final peak = minutes == max && max > 0;
    final color = isToday
        ? SakuraColors.primary
        : minutes > 0
            ? SakuraColors.primary.withValues(alpha: 0.30)
            : SakuraColors.cardBorder;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 14,
          child: minutes > 0
              ? Text(
                  '$minutes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: peak || isToday
                        ? SakuraColors.primary
                        : SakuraColors.inkFaint,
                    fontFeatures: const [
                      FontFeature.tabularFigures()
                    ],
                  ),
                )
              : null,
        ),
        const SizedBox(height: 6),
        Container(
          height: max > 0 && minutes > 0
              ? 14 + 92 * minutes / max
              : 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: color,
            boxShadow: peak
                ? [
                    BoxShadow(
                      color: SakuraColors.primary
                          .withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          letter,
          style: TextStyle(
            fontSize: 10,
            fontWeight:
                isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday
                ? SakuraColors.primary
                : SakuraColors.inkFaint,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday
                ? SakuraColors.primary
                : Colors.transparent,
          ),
        ),
      ],
    );
  }

  /// Plain-language patterns from the already-fetched insights payload
  /// (zero new requests) + a door into the full Insights screen.
  Widget _insightCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SakuraTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INSIGHTS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w600,
              color: SakuraColors.inkFaint,
            ),
          ),
          const SizedBox(height: 12),
          if (!_live)
            Text(
              'Offline — connect to load.',
              style: TextStyle(color: SakuraColors.inkSoft),
            )
          else ...[
            ..._tips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(LucideIcons.sparkles,
                        size: 13,
                        color: SakuraColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: SakuraColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  SakuraPageRoute(
                      builder: (_) =>
                          const InsightsScreen()),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('View insights',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: SakuraColors.primary)),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.arrowRight,
                        size: 13,
                        color: SakuraColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact peak-day card: closes the right column's height gap
  /// on desktop with real content (this week's strongest focus day).
  /// Falls back to a quiet hint when there is nothing to crown yet.
  Widget _peakCard() {
    final now = DateTime.now();
    final mon = now.subtract(Duration(days: now.weekday - 1));
    final byDay = <String, int>{};
    for (final d in _week) {
      final parsed = DateTime.tryParse(d.date);
      if (parsed != null) {
        byDay[_dayKey(parsed)] =
            (byDay[_dayKey(parsed)] ?? 0) + d.minutes;
      }
    }
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    var best = -1;
    var bestMin = 0;
    for (var i = 0; i < 7; i++) {
      final m = byDay[_dayKey(mon.add(Duration(days: i)))] ?? 0;
      if (m > bestMin) {
        bestMin = m;
        best = i;
      }
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: SakuraTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PEAK DAY',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w600,
                  color: SakuraColors.inkFaint,
                ),
              ),
              const Spacer(),
              Icon(LucideIcons.flame,
                  size: 13, color: SakuraColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            best < 0 ? 'No peak yet' : '${names[best]} · $bestMin min',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SakuraColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            best < 0
                ? 'Log focus to crown one.'
                : 'Strongest focus day this week',
            style: TextStyle(fontSize: 12, color: SakuraColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _tagsCard() {
    return Container(      padding: const EdgeInsets.all(18),
      decoration: SakuraTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STRONGEST TAGS',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w600,
              color: SakuraColors.inkFaint,
            ),
          ),
          const SizedBox(height: 12),
          if (!_live || _tags.isEmpty)
            Text(
              _live
                  ? 'Finish tasks to grow tags.'
                  : 'Offline — connect to load.',
              style:
                  TextStyle(color: SakuraColors.inkSoft),
            )
          else
            ..._tags.map(
              (s) => Padding(
                padding:
                    const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SakuraColors.ink,
                            ),
                          ),
                        ),
                        Text(
                          '${s.done}/${s.total}',
                          style: TextStyle(
                            fontSize: 11,
                            color: SakuraColors.inkSoft,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: s.rate,
                        minHeight: 6,
                        backgroundColor:
                            SakuraColors.primarySoft,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                                SakuraColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 16),
      decoration: SakuraTheme.cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: SakuraColors.primary
                  .withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 14, color: SakuraColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SakuraColors.ink,
              fontFeatures: const [
                FontFeature.tabularFigures()
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: SakuraColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}
