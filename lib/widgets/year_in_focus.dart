import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart';
import '../game/token_economy.dart';
import '../theme/sakura_theme.dart';

/// 365-day heatmap that never paints 365 cells at once.
///
/// - [PageView.builder] carousel: each page is a 12-week (~84-day)
///   rolling window, newest last. Swipe left for older periods.
/// - Inside each page a [GridView.builder] paints only visible squares.
/// - [onPageChanged] is the lazy-load hook: fetch that window's chunk
///   from the API/DB, then cache it in [windowCache].
///
/// Dates are derived arithmetically from [anchor] (defaults to today),
/// so the widget works offline with [mockHeatmapData] levels.
class YearInFocusWidget extends StatefulWidget {
  /// Total days covered (default 365).
  final int totalDays;

  /// Days per carousel page (12 weeks ≈ 84; spec says ~90-day window).
  final int windowDays;

  /// Optional pre-loaded levels (0-5) oldest→newest. Missing entries read 0.
  final List<int> levels;

  /// Optional pre-loaded day objects for tap labels. Falls back to
  /// derived dates + [levels] when absent.
  final List<HeatDay> days;

  /// Called when the user lands on a new window. Fetch + setState here.
  /// [windowIndex] 0 = oldest, [pageCount]-1 = newest.
  final Future<void> Function(int windowIndex, DateTime start, DateTime end)?
      onWindowRequested;

  /// Cache for lazily loaded windows: windowIndex → levels.
  final Map<int, List<int>>? windowCache;

  const YearInFocusWidget({
    super.key,
    this.totalDays = 365,
    this.windowDays = 84,
    this.levels = const [],
    this.days = const [],
    this.onWindowRequested,
    this.windowCache,
  });

  int get pageCount => (totalDays / windowDays).ceil();

  @override
  State<YearInFocusWidget> createState() => _YearInFocusWidgetState();
}

class _YearInFocusWidgetState extends State<YearInFocusWidget> {
  late final PageController _pages;
  int _page = 0;
  final Set<int> _requested = {};

  @override
  void initState() {
    super.initState();
    _page = widget.pageCount - 1; // start on newest window
    _pages = PageController(initialPage: _page);
    _request(_page);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _request(int windowIndex) {
    if (_requested.contains(windowIndex)) return;
    _requested.add(windowIndex);
    final cb = widget.onWindowRequested;
    if (cb == null) return;
    final range = _windowRange(windowIndex);
    // Fire-and-forget by design: the host fetches the 90-day chunk
    // from DB/API and setStates its cache. Errors stay silent here.
    cb(windowIndex, range.$1, range.$2).catchError((_) {});
  }

  (DateTime, DateTime) _windowRange(int windowIndex) {
    final anchor = _anchor;
    final newestStart =
        anchor.subtract(Duration(days: widget.windowDays - 1));
    final start = newestStart.subtract(Duration(
        days: (widget.pageCount - 1 - windowIndex) * widget.windowDays));
    return (
      DateTime(start.year, start.month, start.day),
      DateTime(anchor.year, anchor.month, anchor.day)
          .subtract(Duration(
              days: (widget.pageCount - 1 - windowIndex) *
                  widget.windowDays))
    );
  }

  DateTime get _anchor {
    if (widget.days.isNotEmpty) return widget.days.last.date;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _levelForGlobalDay(int globalIndex) {
    final cachedPage = globalIndex ~/ widget.windowDays;
    final cache = widget.windowCache;
    if (cache != null && cache.containsKey(cachedPage)) {
      final list = cache[cachedPage]!;
      final local = globalIndex % widget.windowDays;
      if (local < list.length) return list[local].clamp(0, 5);
    }
    if (globalIndex < widget.levels.length) {
      return widget.levels[globalIndex].clamp(0, 5);
    }
    if (widget.days.isNotEmpty && globalIndex < widget.days.length) {
      return widget.days[globalIndex].level.clamp(0, 5);
    }
    return 0;
  }

  DateTime _dateForGlobalDay(int globalIndex) {
    if (widget.days.isNotEmpty && globalIndex < widget.days.length) {
      return widget.days[globalIndex].date;
    }
    final anchor = _anchor;
    final daysAgo = widget.totalDays - 1 - globalIndex;
    return anchor.subtract(Duration(days: daysAgo));
  }

  @override
  Widget build(BuildContext context) {
    final theme = BloomThemeModel.fromActive();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: SakuraTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'YEAR IN FOCUS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w600,
                    color: SakuraColors.inkFaint),
              ),
              const Spacer(),
              Text(
                '${_page + 1} / ${widget.pageCount}',
                style: TextStyle(
                    fontSize: 10,
                    color: SakuraColors.inkFaint,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 148,
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.pageCount,
              onPageChanged: (i) {
                setState(() => _page = i);
                _request(i); // <-- lazy-load hook: fetch this 90-day chunk
              },
              itemBuilder: (context, page) =>
                  _WindowGrid(
                page: page,
                windowDays: widget.windowDays,
                totalDays: widget.totalDays,
                levelForDay: _levelForGlobalDay,
                dateForDay: _dateForGlobalDay,
                theme: theme,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe for older windows — each page loads its own 12-week chunk.',
            style: TextStyle(
                fontSize: 11, height: 1.5, color: SakuraColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// One 12-week window: lazily built grid, theme-tinted cells.
class _WindowGrid extends StatelessWidget {
  final int page;
  final int windowDays;
  final int totalDays;
  final int Function(int globalIndex) levelForDay;
  final DateTime Function(int globalIndex) dateForDay;
  final BloomThemeModel theme;

  const _WindowGrid({
    required this.page,
    required this.windowDays,
    required this.totalDays,
    required this.levelForDay,
    required this.dateForDay,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final startGlobal = page * windowDays;
    final count =
        (startGlobal + windowDays > totalDays) ? totalDays - startGlobal : windowDays;
    return GridView.builder(
      scrollDirection: Axis.horizontal,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 7 days per column-week row
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: count,
      itemBuilder: (context, i) {
        final g = startGlobal + i;
        final level = levelForDay(g);
        final date = dateForDay(g);
        final now = DateTime.now();
        final isToday = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
        return GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${date.month}/${date.day} · $level task${level == 1 ? '' : 's'}'),
              duration: const Duration(seconds: 2),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.heatColor(level),
              borderRadius: BorderRadius.circular(3.5),
              border: isToday
                  ? Border.all(color: SakuraColors.primary, width: 1.4)
                  : null,
            ),
          ),
        );
      },
    );
  }
}
