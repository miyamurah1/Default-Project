import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/task_repository.dart';
import '../theme/app_motion.dart';
import '../theme/sakura_theme.dart';

/// Modal bottom sheet behind the shell FAB: type a title, pick a folder
/// and tag, and plant immediately into [TaskRepository] (optimistic +
/// locally persisted, so it works offline too).
Future<void> showQuickAddTask(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QuickAddTaskSheet(),
  );
}

const _fallbackFolders = [
  'Productivity',
  'Work',
  'Personal',
  'Health',
  'Learning',
];
const _fallbackTags = [
  'General',
  'Work',
  'Home',
  'Health',
  'Idea',
];

class QuickAddTaskSheet extends StatefulWidget {
  const QuickAddTaskSheet({super.key});

  @override
  State<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<QuickAddTaskSheet> {
  final _title = TextEditingController();
  String _folder = _fallbackFolders.first;
  String _tag = _fallbackTags.first;
  bool _saving = false;

  /// True while the post-plant 🌱 flourish plays; the sheet pops when the
  /// grow animation ends (ticker-driven, no bare timers).
  bool _growing = false;
  String _plantedTitle = '';

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<String> get _folders {
    final set = <String>{
      ..._fallbackFolders,
      ...TaskRepository.instance.tasks.map((t) => t.folder),
    };
    return set.where((f) => f.trim().isNotEmpty).toList()..sort();
  }

  List<String> get _tags {
    final set = <String>{
      ..._fallbackTags,
      ...TaskRepository.instance.tasks.map((t) => t.tag),
    };
    return set.where((t) => t.trim().isNotEmpty).toList()..sort();
  }

  void _plant() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your bloom a name first.')),
      );
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    // Optimistic: the repository inserts the task synchronously, so play
    // the 🌱 immediately instead of blocking on a network round-trip
    // (offline it would otherwise stall until the request times out).
    unawaited(TaskRepository.instance
        .createTask(title: title, folder: _folder, tag: _tag));
    setState(() {
      _plantedTitle = title;
      _growing = true;
    });
    HapticFeedback.mediumImpact();
  }

  /// Called when the 🌱 grow animation completes: dismiss + confirm.
  void _finishPlant() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Planted "$_plantedTitle" 🌱')),
    );
  }

  Widget _sproutFlourish() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.2, end: 1.0),
        duration: AppMotion.bounce,
        curve: AppMotion.bounceCurve,
        onEnd: _finishPlant,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: Transform.scale(scale: v, child: child),
          ),
        ),
        child: Semantics(
          label: 'Task planted',
          child: const Text('🌱', style: TextStyle(fontSize: 34)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return _SpringIn(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: SakuraColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: SakuraColors.cardBorder)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SakuraColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      SakuraColors.primary.withValues(alpha: 0.16),
                      SakuraColors.primarySoft,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SakuraColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.sprout,
                        size: 18, color: SakuraColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Quick plant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: SakuraColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _plant(),
                style: TextStyle(color: SakuraColors.ink),
                decoration: InputDecoration(
                  hintText: 'What needs to bloom?',
                  hintStyle: TextStyle(color: SakuraColors.inkFaint),
                  filled: true,
                  fillColor: SakuraColors.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: SakuraColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: SakuraColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: SakuraColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _PickerRow(
                label: 'FOLDER',
                options: _folders,
                selected: _folder,
                icon: LucideIcons.folder,
                onSelect: (v) => setState(() => _folder = v),
              ),
              const SizedBox(height: 12),
              _PickerRow(
                label: 'TAG',
                options: _tags,
                selected: _tag,
                icon: LucideIcons.tag,
                onSelect: (v) => setState(() => _tag = v),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: _growing
                    ? SizedBox(height: 52, child: _sproutFlourish())
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: SakuraColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _saving ? null : _plant,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(LucideIcons.plus, size: 18),
                        label: Text(
                          _saving ? 'Planting…' : 'Plant bloom',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Springy sheet entrance: content rises + scales in with an overshoot
/// curve so a bottom sheet feels planted rather than merely placed.
class _SpringIn extends StatefulWidget {
  final Widget child;
  const _SpringIn({required this.child});

  @override
  State<_SpringIn> createState() => _SpringInState();
}

class _SpringInState extends State<_SpringIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.pageTurn,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutBack.transform(_c.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 26),
            child: Transform.scale(scale: 0.97 + 0.03 * v, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final IconData icon;
  final ValueChanged<String> onSelect;

  const _PickerRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.icon,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: SakuraColors.inkFaint),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
                color: SakuraColors.inkFaint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              GestureDetector(
                onTap: () => onSelect(o),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AppMotion.toggle,
                  curve: AppMotion.toggleCurve,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: o == selected
                        ? SakuraColors.primary.withValues(alpha: 0.14)
                        : SakuraColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: o == selected
                          ? SakuraColors.primary
                          : SakuraColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    o,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: o == selected
                          ? SakuraColors.primary
                          : SakuraColors.inkSoft,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
