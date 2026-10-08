import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Shared inbox unread state.
///
/// `InboxScreen` publishes the authoritative count after every load /
/// mark-read; the Insights hub badge listens. One source of truth, so the
/// dot clears the instant a message is read instead of only on re-entry.
class InboxStore extends ChangeNotifier {
  InboxStore._();
  static final InboxStore instance = InboxStore._();

  int _unread = 0;
  int get unread => _unread;
  bool get hasUnread => _unread > 0;

  /// Publish a new unread count (no-op when unchanged).
  void setUnread(int n) {
    final v = n < 0 ? 0 : n;
    if (v == _unread) return;
    _unread = v;
    notifyListeners();
  }

  /// Best-effort refresh straight from the API. Offline/errors keep the
  /// last known count rather than flashing the badge off.
  Future<void> refresh() async {
    try {
      final msgs = await BloomApi().fetchInbox(limit: 50);
      setUnread(msgs.where((m) => m.unread).length);
    } catch (_) {
      // Keep the last known state.
    }
  }
}
