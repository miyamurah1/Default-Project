import 'package:flutter/material.dart';

import '../theme/sakura_theme.dart';

/// Shared dialog chrome (your "New folder" reference): white card,
/// radius 28, left-aligned title, underline field, Cancel text +
/// primary pill button right-aligned. Behavior per call site.
class BloomDialog extends StatelessWidget {
  final String title;
  final Widget body;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool confirmEnabled;

  /// Overrides the confirm pill color (e.g. danger red for deletions).
  /// Defaults to the theme primary.
  final Color? confirmColor;

  const BloomDialog({
    super.key,
    required this.title,
    required this.body,
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    this.onConfirm,
    this.confirmEnabled = true,
    this.confirmColor,
  });

  /// Underline field matching the dialog style.
  static InputDecoration fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: SakuraColors.inkFaint),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: SakuraColors.cardBorder),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide:
            BorderSide(color: SakuraColors.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: SakuraColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28)),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 14, 28, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: SakuraColors.ink,
        ),
      ),
      content: body,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            cancelLabel,
            style: TextStyle(
                fontSize: 14, color: SakuraColors.inkSoft),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor ?? SakuraColors.primary,
            padding: const EdgeInsets.symmetric(
                horizontal: 22, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          onPressed:
              confirmEnabled ? (onConfirm ?? () => Navigator.of(context).pop(true)) : null,
          child: Text(
            confirmLabel,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Text confirm: title + message + Cancel/Delete. Returns true/false.
Future<bool> showBloomConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => BloomDialog(
      title: title,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      body: Text(
        message,
        style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: SakuraColors.inkSoft),
      ),
    ),
  );
  return result == true;
}

/// Text input: title + underline field + Cancel/Add. Returns trimmed
/// text, or null on cancel/empty.
Future<String?> showBloomInput(
  BuildContext context, {
  required String title,
  required String hint,
  String confirmLabel = 'Add',
  TextCapitalization capitalization = TextCapitalization.words,
}) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => BloomDialog(
      title: title,
      confirmLabel: confirmLabel,
      onConfirm: () =>
          Navigator.of(ctx).pop(ctrl.text.trim()),
      body: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: capitalization,
        decoration: BloomDialog.fieldDecoration(hint),
        onSubmitted: (_) =>
            Navigator.of(ctx).pop(ctrl.text.trim()),
      ),
    ),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}
