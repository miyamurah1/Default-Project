import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/haptics.dart';
import 'bloom_engine.dart';

/// Single source of truth for Mindful Gamification.
///
/// Holds XP, tokens, streak, rank, and the Flow Combo timer. Pair with
/// `ListenableBuilder` (the app's existing pattern) — no Riverpod needed.
///
/// ```dart
/// final game = GamificationStateNotifier();
/// await game.load();
/// ListenableBuilder(
///   listenable: game,
///   builder: (c, _) => Text('Lv ${game.level} · ${game.tokens}◆'),
/// );
/// game.registerTaskCompletion(); // +XP, advances combo
/// ```
class GamificationStateNotifier extends ChangeNotifier {
  static const _kXp = 'bloom_game_xp';
  static const _kTokens = 'bloom_game_tokens';
  static const _kStreak = 'bloom_game_streak';
  static const _kLastDay = 'bloom_game_last_day';

  /// App-wide singleton — screens share one combo / XP / streak.
  static final GamificationStateNotifier instance =
      GamificationStateNotifier();

  int _totalXp = 0;
  int _tokens = 0;
  int _streak = 0;
  String? _lastDayIso;

  DateTime? _lastCompletionAt;
  int _comboCount = 0;
  DateTime? _comboExpiresAt;
  Timer? _comboTimer;

  final Random _random;

  GamificationStateNotifier({Random? random}) : _random = random ?? Random();

  // --- Reads (cheap getters, safe to call in build) ---

  int get totalXp => _totalXp;
  int get tokens => _tokens;
  int get streak => _streak;

  int get level => BloomEngine.levelForTotalXp(_totalXp);
  double get levelProgress => BloomEngine.progressInLevel(_totalXp);
  int get xpIntoLevel => _totalXp - BloomEngine.totalXpForLevel(level);
  int get xpNeeded => BloomEngine.xpToNext(level);

  BloomRank get rank => BloomEngine.rankForLevel(level);
  String get rankName => BloomEngine.rankName(rank);

  /// Live combo, 0 when expired. Never goes stale: expiry fires notify.
  int get comboCount {
    final exp = _comboExpiresAt;
    if (exp != null && DateTime.now().isAfter(exp)) return 0;
    return _comboCount;
  }

  bool get isComboLive => comboCount > 0;
  DateTime? get comboExpiresAt => _comboExpiresAt;

  // --- Writes ---

  /// Call when a task is completed. Returns the XP granted (incl. bonus).
  /// Chains completions inside [BloomEngine.comboWindow] into a combo.
  int registerTaskCompletion({int baseXp = BloomEngine.baseTaskXp}) {
    final now = DateTime.now();
    final last = _lastCompletionAt;
    if (last != null && now.difference(last) <= BloomEngine.comboWindow) {
      _comboCount++;
    } else {
      _comboCount = 1;
    }
    _lastCompletionAt = now;
    _comboExpiresAt = now.add(BloomEngine.comboWindow);
    _scheduleComboExpiry();

    final gain = BloomEngine.xpForCombo(baseXp, _comboCount);
    _totalXp += gain;
    _persist();
    notifyListeners();
    return gain;
  }

  /// Daily ritual → variable token drop (70/25/5). Adds tokens, returns roll.
  MysteryReward claimDailyRitual() {
    final reward = BloomEngine.rollMysteryBloom(_random);
    _tokens += reward.tokens;
    _persist();
    notifyListeners();
    return reward;
  }

  /// Call once per app foreground (or after a recovery task). Handles
  /// same-day (no-op), next-day (+1), and broken streak (reset to 1).
  ///
  /// Milestones feel like milestones: 7/30/100-day streaks fire the
  /// celebration fanfare (heavy impact); an ordinary next-day tick fires
  /// the confirm tick. Same-day no-ops and broken resets stay silent —
  /// haptics reward progress, never punish a miss.
  void markDailyActive([DateTime? now]) {
    final day = _dayKey(now ?? DateTime.now());
    if (_lastDayIso == day) return;
    var grown = false;
    if (_lastDayIso == null) {
      _streak = 1;
      grown = true;
    } else {
      final last = DateTime.tryParse(_lastDayIso!);
      if (last == null) {
        _streak = 1;
        grown = true;
      } else {
        final gap = _dateOnly(DateTime.parse(day))
            .difference(_dateOnly(last))
            .inDays;
        if (gap == 1) {
          _streak += 1;
          grown = true;
        } else {
          _streak = 1;
        }
      }
    }
    _lastDayIso = day;
    _persist();
    notifyListeners();
    if (!grown) return;
    if (_streak == 7 || _streak == 30 || _streak == 100) {
      AppHaptics.celebrate();
    } else {
      AppHaptics.confirm();
    }
  }

  void setStreak(int value) {
    _streak = value < 0 ? 0 : value;
    _persist();
    notifyListeners();
  }

  void addTokens(int amount) {
    _tokens += amount;
    _persist();
    notifyListeners();
  }

  bool spendTokens(int amount) {
    if (_tokens < amount) return false;
    _tokens -= amount;
    _persist();
    notifyListeners();
    return true;
  }

  void addXp(int amount) {
    _totalXp += amount;
    _persist();
    notifyListeners();
  }

  /// Demo helper: max the profile to Full Bloom so the whole app can be
  /// seen at Lv 100 (Sakura, 5/5 season, live x5 combo, petals on).
  /// No server writes — local game juice only.
  void debugFullBloom() {
    _totalXp = BloomEngine.totalXpForLevel(BloomEngine.maxLevel);
    _tokens += 2500;
    if (_streak < 12) _streak = 12;
    final now = DateTime.now();
    _comboCount = 5;
    _lastCompletionAt = now;
    _comboExpiresAt = now.add(BloomEngine.comboWindow);
    _scheduleComboExpiry();
    _lastDayIso = _dayKey(now);
    _persist();
    notifyListeners();
  }

  /// Demo helper: back to a fresh Seedling.
  void debugReset() {
    _comboTimer?.cancel();
    _totalXp = 0;
    _tokens = 0;
    _streak = 1;
    _comboCount = 0;
    _lastCompletionAt = null;
    _comboExpiresAt = null;
    _lastDayIso = _dayKey(DateTime.now());
    _persist();
    notifyListeners();
  }

  // --- Persistence (best-effort, never throws into UI) ---

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalXp = prefs.getInt(_kXp) ?? 0;
      _tokens = prefs.getInt(_kTokens) ?? 0;
      _streak = prefs.getInt(_kStreak) ?? 0;
      _lastDayIso = prefs.getString(_kLastDay);
      notifyListeners();
    } catch (_) {
      // Offline / first run: keep zeros.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kXp, _totalXp);
      await prefs.setInt(_kTokens, _tokens);
      await prefs.setInt(_kStreak, _streak);
      if (_lastDayIso != null) await prefs.setString(_kLastDay, _lastDayIso!);
    } catch (_) {
      // Persistence is a bonus — gameplay continues in memory.
    }
  }

  void _scheduleComboExpiry() {
    _comboTimer?.cancel();
    final exp = _comboExpiresAt;
    if (exp == null) return;
    final wait = exp.difference(DateTime.now());
    if (wait.isNegative) {
      _comboCount = 0;
      return;
    }
    // Cap the OS timer at 15 min — exact, one shot, cheap.
    _comboTimer = Timer(wait, () {
      _comboCount = 0;
      _comboExpiresAt = null;
      notifyListeners();
    });
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void dispose() {
    _comboTimer?.cancel();
    super.dispose();
  }
}
