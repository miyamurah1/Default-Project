import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart';
import '../data/task_repository.dart';
import '../game/bloom_game_colors.dart';
import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';
import 'bloom_dialog.dart';
import 'bloom_sheet.dart';
import 'bloom_snackbar.dart';
import 'motion.dart';
import 'task_card.dart';

/// Shared Kanban board: TO-DO / IN PROGRESS / DONE.
///
/// Wide screens (desktop, your reference): three columns side by side,
/// each scrolling on its own. Narrow screens: the segmented tab view.
/// Used by Home and by Board (which now opens this instead of the
/// old quadrant grid).
class KanbanBoard extends StatelessWidget {
  final List<Task> todo;
  final List<Task> progress;
  final List<Task> done;
  final ValueChanged<Task> onTap;
  final ValueChanged<Task> onOpen;
  final void Function(Subtask, bool) onToggleSub;
  final ValueChanged<Task> onTimer;
  final double breakpoint;
  final double boardHeight;

  /// Soft WIP limit for IN PROGRESS: a signal, never a block. Moves
  /// into progress happen server-side (rules engine), where the client
  /// can't gate them — so an over-limit column says so out loud
  /// (`4/3` + one calm line) instead of pretending to enforce.
  static const int wipLimit = 3;
  static bool overWip(int n) => n > wipLimit;

  /// Prefix for timer-chip hero tags (`home-focus-`, `board-focus-`).
  /// Null disables the flight. Prefixes are per-screen so the same
  /// task kept alive on two tabs can never share a tag.
  final String? heroPrefix;

  /// When true the wide board fills its parent (caller must bound the
  /// height, e.g. with Expanded). Otherwise it takes [boardHeight].
  final bool expand;

  /// When true the segmented tab view is always used (Home), even on
  /// desktop. The side-by-side board then lives on Board only.
  final bool tabsOnly;

  const KanbanBoard({
    super.key,
    required this.todo,
    required this.progress,
    required this.done,
    required this.onTap,
    required this.onOpen,
    required this.onToggleSub,
    required this.onTimer,
    this.breakpoint = 900,
    this.boardHeight = 560,
    this.expand = false,
    this.tabsOnly = false,
    this.heroPrefix,
  });

  @override
  Widget build(BuildContext context) {
    // Urgent float: overdue + due-today rise to the top of TO-DO on
    // every layout (wide columns and phone tabs alike). Stable inside
    // each band, so manual position order is never scrambled.
    final floatedTodo = floatUrgent(todo);
    if (tabsOnly) return _narrow(floatedTodo);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= breakpoint) {
          final row = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BoardColumn(
                label: 'TO-DO',
                tasks: floatedTodo,
                accent: SakuraColors.primary,
                onTap: onTap,
                onOpen: onOpen,
                onToggleSub: onToggleSub,
                onTimer: onTimer,
                heroPrefix: heroPrefix,
              ),
              const SizedBox(width: 12),
              _BoardColumn(
                label: 'IN PROGRESS',
                tasks: progress,
                accent: BloomGameColors.kanbanProgress,
                onTap: onTap,
                onOpen: onOpen,
                onToggleSub: onToggleSub,
                onTimer: onTimer,
                heroPrefix: heroPrefix,
                wipLimit: KanbanBoard.wipLimit,
              ),
              const SizedBox(width: 12),
              _BoardColumn(
                label: 'DONE',
                tasks: done,
                accent: BloomGameColors.kanbanDone,
                onTap: onTap,
                onOpen: onOpen,
                onToggleSub: onToggleSub,
                onTimer: onTimer,
                heroPrefix: heroPrefix,
              ),
            ],
          );
          if (expand) return row;
          return SizedBox(height: boardHeight, child: row);
        }
        return _narrow(floatedTodo);
      },
    );
  }

  /// Segmented tab view (phones, and Home on all widths).
  Widget _narrow([List<Task>? floatedTodo]) {
    return _NarrowTabs(
      todo: floatedTodo ?? todo,
      progress: progress,
      done: done,
      onTap: onTap,
      onOpen: onOpen,
      onToggleSub: onToggleSub,
      onTimer: onTimer,
      heroPrefix: heroPrefix,
    );
  }
}

class _NarrowTabs extends StatefulWidget {
  final List<Task> todo;
  final List<Task> progress;
  final List<Task> done;
  final ValueChanged<Task> onTap;
  final ValueChanged<Task> onOpen;
  final void Function(Subtask, bool) onToggleSub;
  final ValueChanged<Task> onTimer;
  final String? heroPrefix;

  const _NarrowTabs({
    required this.todo,
    required this.progress,
    required this.done,
    required this.onTap,
    required this.onOpen,
    required this.onToggleSub,
    required this.onTimer,
    this.heroPrefix,
  });

  @override
  State<_NarrowTabs> createState() => _NarrowTabsState();
}

class _NarrowTabsState extends State<_NarrowTabs> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // One visible tab at a time, each shrink-wrapped to its real
    // content: the section is exactly as tall as the SELECTED list.
    // (IndexedStack sizes to the tallest tab, which strands a void
    // below short tabs — same disease as the old height estimate.)
    // maintainState keeps offstage tabs alive so expanded cards and
    // toggles survive tab switches; maintainSize false gives them
    // zero height. No estimates, no caps anywhere.
    final over = KanbanBoard.overWip(widget.progress.length);
    Widget tab(int index, List<Task> tasks) => Visibility(
          visible: _tab == index,
          maintainState: true,
          maintainAnimation: false,
          maintainSize: false,
          maintainSemantics: false,
          maintainInteractivity: false,
          child: _TaskList(
              tasks: tasks,
              onTap: widget.onTap,
              onOpen: widget.onOpen,
              onToggleSub: widget.onToggleSub,
              onTimer: widget.onTimer,
              heroPrefix: widget.heroPrefix),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SegmentedKanbanBar(
          todoCount: widget.todo.length,
          progressCount: widget.progress.length,
          doneCount: widget.done.length,
          selected: _tab,
          onSelect: (i) => setState(() => _tab = i),
          progressOver: over,
        ),
        if (over && _tab == 1) ...[
          const SizedBox(height: 8),
          Text(
            'Over the limit — finish one before starting more.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: SakuraColors.inkSoft,
            ),
          ),
        ],
        const SizedBox(height: 16),
        tab(0, widget.todo),
        tab(1, widget.progress),
        tab(2, widget.done),
      ],
    );
  }
}

class _BoardColumn extends StatelessWidget {
  final String label;
  final List<Task> tasks;
  final Color accent;
  final ValueChanged<Task> onTap;
  final ValueChanged<Task> onOpen;
  final void Function(Subtask, bool) onToggleSub;
  final ValueChanged<Task> onTimer;
  final String? heroPrefix;

  /// Soft cap shown as `n/limit` + one calm line. Null = no cap.
  final int? wipLimit;

  const _BoardColumn({
    required this.label,
    required this.tasks,
    required this.accent,
    required this.onTap,
    required this.onOpen,
    required this.onToggleSub,
    required this.onTimer,
    this.heroPrefix,
    this.wipLimit,
  });

  @override
  Widget build(BuildContext context) {
    final over =
        wipLimit != null && tasks.length > wipLimit!;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(
          color: SakuraColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border(
            top: BorderSide(color: accent, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                      color: SakuraColors.ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SakuraColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    over
                        ? '${tasks.length}/$wipLimit'
                        : '${tasks.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: SakuraColors.primary,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (over) ...[
              const SizedBox(height: 6),
              Text(
                'Over the limit — finish one before starting more.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: SakuraColors.inkSoft,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: _TaskList(
                tasks: tasks,
                onTap: onTap,
                onOpen: onOpen,
                onToggleSub: onToggleSub,
                onTimer: onTimer,
                heroPrefix: heroPrefix,
                scrollable: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedKanbanBar extends StatelessWidget {
  final int todoCount;
  final int progressCount;
  final int doneCount;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Soft WIP signal on the PROGRESS segment (`4/3`).
  final bool progressOver;

  const _SegmentedKanbanBar({
    required this.todoCount,
    required this.progressCount,
    required this.doneCount,
    required this.selected,
    required this.onSelect,
    this.progressOver = false,
  });

  @override
  Widget build(BuildContext context) {
    // Tappable segments (no TabController): same pill styling the
    // TabBar had, driven by the parent tab index.
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SakuraColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SakuraColors.cardBorder),
      ),
      child: Row(
        children: [
          _segment(0, 'TO-DO ($todoCount)'),
          _segment(
              1,
              progressOver
                  ? 'PROGRESS ($progressCount/${KanbanBoard.wipLimit})'
                  : 'PROGRESS ($progressCount)'),
          _segment(2, 'DONE ($doneCount)'),
        ],
      ),
    );
  }

  Widget _segment(int index, String label) {
    final active = index == selected;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          onTap: () => onSelect(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppMotion.nav,
            curve: AppMotion.toggleCurve,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? SakuraColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.8,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? Colors.white : SakuraColors.inkFaint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final ValueChanged<Task> onTap;
  final ValueChanged<Task> onOpen;
  final void Function(Subtask, bool) onToggleSub;
  final ValueChanged<Task> onTimer;
  final bool scrollable;
  final String? heroPrefix;

  /// Fixed danger crimson — mirrors Settings so "delete" reads as danger
  /// on every theme (never the theme primary).
  static const _swipeDelete = Color(0xFFD33A4E);

  const _TaskList(
      {required this.tasks,
      required this.onTap,
      required this.onOpen,
      required this.onToggleSub,
      required this.onTimer,
      this.scrollable = false,
      this.heroPrefix});

  /// Delete with a 4s UNDO window (habit-deletion pattern): the backup
  /// task + subtask titles are captured before the delete, and UNDO
  /// re-plants them (fresh server ids) with status restored.
  Future<bool> _confirmDelete(BuildContext context, Task t) async {
    final yes = await showBloomConfirm(
      context,
      title: 'Delete this task?',
      message:
          '"${t.title}" and its subtasks, notes and history go with it.',
      cancelLabel: 'Keep',
    );
    if (!yes) return false;
    final backupSubs =
        t.subtasks?.map((s) => s.title).toList() ?? const <String>[];
    await TaskRepository.instance.deleteTask(t.id);
    if (!context.mounted) return true;
    showBloomSnackBar(
      context,
      'Deleted "${t.title}".',
      duration: const Duration(seconds: 4),
      actionLabel: 'UNDO',
      onAction: () async {
        final restored = await TaskRepository.instance.createTask(
          title: t.title,
          folder: t.folder,
          tag: t.tag,
          description: t.description,
          priority: t.priority,
          recurring: t.recurring,
          dueAt: t.dueAt,
        );
        if (t.status != 'todo') {
          await TaskRepository.instance.moveTask(restored.id, t.status);
        }
        for (final st in backupSubs) {
          await TaskRepository.instance.createSubtask(restored.id, st);
        }
      },
    );
    return true;
  }

  Future<void> _setDue(Task t, DateTime due) =>
      TaskRepository.instance.updateTask(t.id, dueAt: due);

  Future<void> _pickDate(BuildContext context, Task t) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: t.dueAt ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) await _setDue(t, picked);
  }

  /// Long-press quick menu: reschedule or delete without opening detail.
  Future<void> _showMenu(BuildContext context, Task t) async {
    await showBloomSheet<void>(
      context,
      SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            _MenuAction(
              icon: LucideIcons.calendarCheck,
              label: 'Due today',
              onTap: () {
                Navigator.of(context).pop();
                _setDue(t, DateTime.now());
              },
            ),
            _MenuAction(
              icon: LucideIcons.calendarPlus,
              label: 'Due tomorrow',
              onTap: () {
                Navigator.of(context).pop();
                _setDue(t, DateTime.now().add(const Duration(days: 1)));
              },
            ),
            _MenuAction(
              icon: LucideIcons.calendarDays,
              label: 'Set date…',
              onTap: () {
                Navigator.of(context).pop();
                _pickDate(context, t);
              },
            ),
            _MenuAction(
              icon: LucideIcons.trash2,
              label: 'Delete',
              danger: true,
              onTap: () {
                Navigator.of(context).pop();
                _confirmDelete(context, t);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _swipeBackground({required bool complete}) {
    final color = complete ? BloomGameColors.kanbanDone : _swipeDelete;
    return Semantics(
      label: complete ? 'Swipe to complete' : 'Swipe to delete',
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: complete ? Alignment.centerLeft : Alignment.centerRight,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              complete ? LucideIcons.checkCircle2 : LucideIcons.trash2,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              complete ? 'Complete' : 'Delete',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      // Tasks motif (sprout): circle badge + title + guidance — the same
      // card language as the folders/inbox/habits empties, with a glyph
      // that belongs to tasks alone.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    SakuraColors.primary.withValues(alpha: 0.22),
                    SakuraColors.primary.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.sprout,
                  size: 22, color: SakuraColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'A quiet garden',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: SakuraColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              'Plant your first bloom above —\nsmall steps grow here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: SakuraColors.inkSoft),
            ),
          ],
        ),
      );
    }
    // Entrance stagger for the first screenful only — rows past 6 render
    // instantly so a long Done column doesn't stack timers + fades.
    Widget card(int index) {
      final task = tasks[index];
      return Dismissible(
        key: ValueKey('dismiss_${task.id}'),
        direction: DismissDirection.horizontal,
        background: _swipeBackground(complete: true),
        secondaryBackground: _swipeBackground(complete: false),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            // Right swipe completes; never reopens an already-done task.
            if (task.status != 'done') onTap(task);
            return false; // snap back — the repository re-sorts the lists
          }
          return _confirmDelete(context, task);
        },
        child: Entrance(
          key: ValueKey('entrance_${task.id}'),
          onceKey: 'kanban-${task.id}',
          delayMs: index < 6 ? (index * 60).clamp(0, 300) : 0,
          child: TaskCard(
            task: task,
            onToggle: () => onTap(task),
            onOpen: () => onOpen(task),
            onToggleSub: (s, done) => onToggleSub(s, done),
            onTimerTap: () => onTimer(task),
            onLongPress: () => _showMenu(context, task),
            heroTag: heroPrefix == null ? null : '$heroPrefix${task.id}',
          ),
        ),
      );
    }
    // Desktop columns scroll on their own; the tab view stays
    // measured by the page (shrink-wrapped, never scrolling inside).
    if (scrollable) {
      return ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) => card(index),
      );
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: tasks.length,
      itemBuilder: (context, index) => card(index),
    );
  }
}

/// One row inside the long-press task menu.
class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? _TaskList._swipeDelete
        : SakuraColors.ink;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
