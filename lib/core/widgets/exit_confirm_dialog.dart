import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../device/form_factor.dart';
import '../theme/app_colors.dart';
import 'neon_focus_card.dart';

Future<bool> showNeonConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Hayır',
  String confirmLabel = 'Evet',
  Color confirmColor = AppColors.danger,
}) async {
  // The dialog can be opened by a held D-Pad key, so ignore activations that
  // arrive from the same physical press that triggered it.
  final DateTime acceptingFrom = FormFactor.isPhone
      ? DateTime.now()
      : DateTime.now().add(const Duration(milliseconds: 700));
  bool isAccepting() => DateTime.now().isAfter(acceptingFrom);

  final bool? confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.45), width: 2),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: NeonFocusCard(
                  autofocus: true,
                  glowColor: AppColors.neonCyan,
                  focusedScale: 1.06,
                  unfocusedOpacity: 0.75,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onActivate: () {
                    if (isAccepting()) {
                      Navigator.of(dialogContext).pop(false);
                    }
                  },
                  child: Center(
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NeonFocusCard(
                  glowColor: confirmColor,
                  focusedScale: 1.06,
                  unfocusedOpacity: 0.75,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onActivate: () {
                    if (isAccepting()) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: Center(
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<bool> showExitConfirmDialog(BuildContext context) {
  return showNeonConfirmDialog(
    context: context,
    title: 'Çıkış Onayı',
    message: 'Çıkış Yapmak İstiyor musunuz?',
    cancelLabel: 'Hayır',
    confirmLabel: 'Evet',
  );
}

Future<void> handleAppExit(BuildContext context) async {
  final bool shouldExit = await showExitConfirmDialog(context);
  if (shouldExit) {
    await SystemNavigator.pop();
  }
}

Future<void> popToPreviousPage(BuildContext context) async {
  final NavigatorState navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  }
}
