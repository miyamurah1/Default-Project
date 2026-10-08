import 'package:flutter/material.dart';

import '../data/api_client.dart' show Subtask;
import '../data/mock_data.dart' show Task;
import '../game/game.dart';
import '../theme/sakura_theme.dart';
import 'kanban_board.dart';

/// Clean task-flow section for the Home hub.
///
/// Thin wrapper over [KanbanBoard] (tabbed, Home-style) with the
/// combo juice applied. All card UI lives in `kanban_board.dart` /
/// `task_card.dart` — this widget is just the section header + board.
class TaskFlowList extends StatelessWidget {
  final List<Task> todo;
  final List<Task> progress;
  final List<Task> done;
  final ValueChanged<Task> onTap;
  final ValueChanged<Task> onOpen;
  final void Function(Subtask, bool) onToggleSub;
  final ValueChanged<Task> onTimer;

  /// Prefix for timer-chip hero tags. Home passes `'home-focus-'`;
  /// the timer push must use the identical prefix + task id.
  final String? heroPrefix;

  const TaskFlowList({
    super.key,
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
  Widget build(BuildContext context) {
    // Hoisted OUT of the listener: on an XP tick the builder creates a
    // fresh FlowStateJuiceWidget but reuses this exact KanbanBoard
    // instance, so Flutter's identical-widget check skips the whole card
    // subtree — combo juice repaints the glow, never the 30 cards.
    final board = KanbanBoard(
      todo: todo,
      progress: progress,
      done: done,
      onTap: onTap,
      onOpen: onOpen,
      onToggleSub: onToggleSub,
      onTimer: onTimer,
      tabsOnly: true,
      heroPrefix: heroPrefix,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S FLOW — tap a card to toggle done",
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w600,
            color: SakuraColors.inkFaint,
          ),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: GamificationStateNotifier.instance,
          builder: (context, _) => FlowStateJuiceWidget(
            comboLevel: GamificationStateNotifier.instance.comboCount,
            child: board,
          ),
        ),
      ],
    );
  }
}
