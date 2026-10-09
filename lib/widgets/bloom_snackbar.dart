import 'package:flutter/material.dart';

/// One transient-message helper for the whole app: always replaces the
/// current snackbar instead of queuing behind it, so rapid taps (complete,
/// undo, settle, plant) never stack stale toasts over the live screen.
///
/// Use everywhere instead of calling `ScaffoldMessenger..showSnackBar`
/// directly. Error paths that fire at most once per screen may keep the
/// raw call; anything tied to a tap must come through here.
void showBloomSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}
