import 'package:flutter/material.dart';

import '../theme/sakura_theme.dart';

/// One bottom-sheet chrome for the whole app: native drag handle,
/// safe-area padding, standard 24px top radius, theme surface.
///
/// Use for every sheet. Sheets with text input additionally set
/// `isScrollControlled: true` at the call site and pad
/// `MediaQuery.viewInsets.bottom` inside — see the habit sheets and
/// the target editor for the pattern.
Future<T?> showBloomSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: SakuraColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => child,
  );
}
