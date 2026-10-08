import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/api_client.dart';
import '../data/mock_data.dart';
import '../data/task_repository.dart';
import '../theme/sakura_theme.dart';
import '../widgets/motion.dart';
import '../widgets/task_card.dart';
import 'focus_timer_screen.dart';
import 'task_detail_screen.dart';

/// Folder detail — tasks inside one folder + add box.
/// Tap a card toggles done (bumps the heatmap like a git commit).
class FolderDetailScreen extends StatefulWidget {
  final BloomFolder folder;
  const FolderDetailScreen({super.key, required this.folder});

  @override
  State<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends State<FolderDetailScreen> {
  final _repo = TaskRepository.instance;
  final _ctrl = TextEditingController();
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_sync);
    _load();
  }

  @override
  void dispose() {
    _repo.removeListener(_sync);
    _ctrl.dispose();
    super.dispose();
  }

  /// Repository -> this folder's tasks (fires on optimistic edits too).
  void _sync() {
    if (!mounted) return;
    setState(() {
      _tasks = _repo.tasksForFolder(widget.folder.name);
      _loading = false;
    });
  }

  Future<void> _load() async {
    await _repo.loadRemote(withDetails: true);
    if (!mounted) return;
    _sync();
  }

  Future<void> _add() async {
    final title = _ctrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a task title first.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    _ctrl.clear();
    // Optimistic + offline-safe via the repository.
    await _repo.createTask(title: title, folder: widget.folder.name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "$title".')),
      );
    }
  }

  Future<void> _toggle(Task t) => _repo.moveTask(t.id, nextStatus(t));

  void _openDetail(Task t) {
    Navigator.of(context)
        .push(SakuraPageRoute(builder: (_) => TaskDetailScreen(task: t)))
        .then((_) => _load());
  }

  Future<void> _toggleSub(Subtask s, bool done) =>
      _repo.setSubtaskDone(s.id, done);

  void _openTimer(Task t) {
    Navigator.of(context)
        .push(SakuraPageRoute(
            builder: (_) =>
                FocusTimerScreen(task: t, heroTag: 'folder-focus-${t.id}')))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakuraColors.background,
      appBar: AppBar(
        backgroundColor: SakuraColors.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SakuraColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: SakuraColors.cardBorder),
            ),
            child: Tooltip(
              message: 'Back',
              child: Icon(LucideIcons.arrowLeft,
                  size: 18, color: SakuraColors.ink),
            ),
          ),
        ),
        title: Text(
          widget.folder.name,
          style: TextStyle(
              fontWeight: FontWeight.w800, color: SakuraColors.ink),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Add a task to ${widget.folder.name}…',
                      filled: true,
                      fillColor: SakuraColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: SakuraColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: SakuraColors.cardBorder),
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: SakuraColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.plus,
                        size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: SakuraColors.primary
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(LucideIcons.leaf,
                                  size: 22,
                                  color: SakuraColors.primary),
                            ),
                            const SizedBox(height: 12),
                            Text('No tasks yet',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: SakuraColors.ink)),
                            const SizedBox(height: 6),
                            Text('Add the first one above.',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: SakuraColors.inkSoft)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: _tasks.length,
                          itemBuilder: (ctx, i) => TaskCard(
                            task: _tasks[i],
                            onToggle: () => _toggle(_tasks[i]),
                            onOpen: () => _openDetail(_tasks[i]),
                            onToggleSub: (s, done) =>
                                _toggleSub(s, done),
                            onTimerTap: () =>
                                _openTimer(_tasks[i]),
                            heroTag: 'folder-focus-${_tasks[i].id}',
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
