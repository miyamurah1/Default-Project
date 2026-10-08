import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../data/api_client.dart';
import '../data/auth_store.dart';
import '../theme/sakura_theme.dart';

Color _colorForRun(String status) {
  switch (status) {
    case 'success':
      return const Color(0xFF1B7A3D);
    case 'skipped':
      return SakuraColors.inkFaint;
    case 'failed':
    default:
      return SakuraColors.primary;
  }
}

String _detailForRun(RuleRun r) {
  final d = r.detail;
  if (r.status == 'skipped') {
    return '${d['reason'] ?? 'condition did not match'}';
  }
  if (r.status == 'failed') {
    return '${d['error'] ?? 'failed'}';
  }
  final actions = (d['actions'] as List?) ?? [];
  if (actions.isEmpty) return 'ran';
  return actions
      .map((a) => actionLabel(
          Map<String, dynamic>.from(a as Map)))
      .join(' · ');
}

/// Execution log for one flow — every firing, newest first.
class RuleRunsScreen extends StatefulWidget {
  final FlowRule rule;
  const RuleRunsScreen({super.key, required this.rule});

  @override
  State<RuleRunsScreen> createState() => _RuleRunsScreenState();
}

class _RuleRunsScreenState extends State<RuleRunsScreen> {
  final _api = BloomApi();
  List<RuleRun> _runs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final runs = await _api.fetchRuns(widget.rule.id);
      if (!mounted) return;
      setState(() {
        _runs = runs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is AuthExpiredException) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load runs.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('MMM d · HH:mm');
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
          widget.rule.name,
          style: TextStyle(
              fontWeight: FontWeight.w800, color: SakuraColors.ink),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _runs.isEmpty
              ? Center(
                  child: Text(
                    'No runs yet — do the trigger and watch it fire.',
                    style:
                        TextStyle(color: SakuraColors.inkSoft),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: _runs.length,
                    itemBuilder: (ctx, i) {
                      final r = _runs[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration:
                            SakuraTheme.cardDecoration(),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: _colorForRun(r.status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.taskTitle.isEmpty
                                        ? r.status.toUpperCase()
                                        : r.taskTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: SakuraColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${r.status} · ${_detailForRun(r)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: SakuraColors.inkSoft,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    timeFmt.format(
                                        r.createdAt.toLocal()),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: SakuraColors.inkFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(LucideIcons.history,
                                size: 14,
                                color: SakuraColors.inkFaint),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
