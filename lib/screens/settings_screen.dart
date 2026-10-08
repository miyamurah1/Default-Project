import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../data/api_client.dart';
import '../data/auth_store.dart';
import '../data/calendar_export.dart';
import '../data/reminders.dart';
import '../game/game.dart';
import '../theme/sakura_theme.dart';
import '../widgets/bloom_dialog.dart';
/// Settings — profile, logout, and the Play-required account deletion.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _deleting = false;
  bool _exporting = false;
  bool _exportingIcs = false;
  bool _reminderOn = false;
  bool _reminderBusy = false;

  @override
  void initState() {
    super.initState();
    ReminderService.instance.load().then((_) {
      if (mounted) {
        setState(
            () => _reminderOn = ReminderService.instance.enabled);
      }
    });
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() => _reminderBusy = true);
    try {
      final ok = await ReminderService.instance.setEnabled(value);
      if (!mounted) return;
      setState(() {
        _reminderOn = ReminderService.instance.enabled;
      });
      if (value && !ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Notifications blocked — allow them in system settings, then retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reminderBusy = false);
    }
  }

  /// Fixed danger crimson — never the theme primary, so Delete reads
  /// as danger even on green (Kyoto) or pink (Midnight) themes.
  static const _danger = Color(0xFFD33A4E);

  Future<void> _logout() async {
    ThemeStore.instance.resetToDefault();
    await AuthStore.instance.logout();
    // AuthGate swaps to login; this tree is discarded.
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final data = await BloomApi().fetchExport();
      final text =
          const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: text));
      final n = (data['tasks'] as List?)?.length ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Copied $n tasks + history to clipboard.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is AuthExpiredException) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCalendar() async {
    setState(() => _exportingIcs = true);
    try {
      final tasks = await BloomApi().fetchTasks(withDetails: false);
      final n = datedCount(tasks);
      if (!mounted) return;
      if (n == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No dated tasks — set a due date first.')),
        );
        return;
      }
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Calendar files need the mobile or desktop app.')),
        );
        return;
      }
      final file = await File(
              '${Directory.systemTemp.path}/daily-bloom.ics')
          .writeAsString(buildIcs(tasks));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/calendar')],
          text: 'My Daily Bloom tasks',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is AuthExpiredException) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar export failed.')),
      );
    } finally {
      if (mounted) setState(() => _exportingIcs = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ctrl = TextEditingController();
    var typedOk = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => BloomDialog(
          title: 'Delete account?',
          confirmLabel: 'Delete',
          confirmEnabled: typedOk,
          confirmColor: _SettingsScreenState._danger,
          onConfirm: () => Navigator.of(ctx).pop(true),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This removes your login, tokens, inbox and flows. Task history goes anonymous; shared tasks stay. This cannot be undone.',
                style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: SakuraColors.inkSoft),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.characters,
                decoration: BloomDialog.fieldDecoration(
                    'Type DELETE to confirm'),
                onChanged: (v) =>
                    setSheet(() => typedOk = v.trim() == 'DELETE'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      ThemeStore.instance.resetToDefault();
      await AuthStore.instance.deleteAccount();
      // AuthGate takes it from here.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e is AuthException
                ? e.message
                : 'Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  /// Crash-proof avatar initial (empty strings have no `.first`).
  String _initial(AuthUser? user) {
    final src = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (user?.email ?? '');
    final t = src.trim();
    if (t.isEmpty) return '✿';
    return t.characters.first.toUpperCase();
  }

  ButtonStyle get _actionStyle => OutlinedButton.styleFrom(
        foregroundColor: SakuraColors.primary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: SakuraColors.cardBorder),
      );

  @override
  Widget build(BuildContext context) {
    final user = AuthStore.instance.user;
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
        title: Text('Settings',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: SakuraColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SakuraTheme.cardDecoration(),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: SakuraColors.primarySoft,
                  child: Text(
                    _initial(user),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: SakuraColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName
                            : 'Bloomer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SakuraColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: SakuraColors.inkSoft),
                      ),
                      const SizedBox(height: 6),
                      ListenableBuilder(
                        listenable:
                            GamificationStateNotifier.instance,
                        builder: (context, _) {
                          final game =
                              GamificationStateNotifier
                                  .instance;
                          final xp = game.level >=
                                  BloomEngine.maxLevel
                              ? 'MAX'
                              : '${game.xpIntoLevel}/${game.xpNeeded} XP';
                          return Text(
                            '${game.rankName} · Lv ${game.level} — $xp · ◆ ${game.tokens} · ${game.streak}d streak',
                            style: TextStyle(
                              fontSize: 11,
                              color: SakuraColors.inkFaint,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SakuraTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  style: _actionStyle,
                  onPressed: _logout,
                  icon: const Icon(LucideIcons.logOut,
                      size: 15),
                  label: const Text('Log out',
                      style: TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: _actionStyle,
                  onPressed: _exporting ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          height: 15,
                          width: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : const Icon(LucideIcons.download,
                          size: 15),
                  label: const Text('Export my data',
                      style: TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: _actionStyle,
                  onPressed: _exportingIcs ? null : _exportCalendar,
                  icon: _exportingIcs
                      ? const SizedBox(
                          height: 15,
                          width: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                      : const Icon(LucideIcons.calendarDays,
                          size: 15),
                  label: const Text('Export calendar (.ics)',
                      style: TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SakuraTheme.cardDecoration(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SakuraColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.bell,
                      size: 15, color: SakuraColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily reminder',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: SakuraColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'One gentle nudge at 9:00 — never more.',
                        style: TextStyle(
                            fontSize: 12, color: SakuraColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _reminderOn,
                  onChanged:
                      _reminderBusy ? null : (v) => _toggleReminder(v),
                  activeThumbColor: SakuraColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _danger.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.triangleAlert,
                        size: 13, color: _danger),
                    SizedBox(width: 7),
                    Text(
                      'DANGER ZONE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: _danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Deleting removes your login, tokens, inbox and flows. This cannot be undone.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: SakuraColors.inkSoft),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14))),
                  onPressed:
                      _deleting ? null : _confirmDelete,
                  icon: _deleting
                      ? const SizedBox(
                          height: 15,
                          width: 15,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(LucideIcons.trash2,
                          size: 15),
                  label: Text(
                      _deleting ? 'Deleting…' : 'Delete account',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Daily Bloom 1.0.0 · your data stays yours —\nexport or delete it anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: SakuraColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}
