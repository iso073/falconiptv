import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../data/parental_control_repository.dart';

/// Collects a numeric PIN with the D-Pad, since TV remotes have no keypad.
Future<String?> showPinEntryDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _PinEntryDialog(title: title, message: message),
  );
}

class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  // The dialog can be opened by a held OK press; ignore that same press.
  final DateTime _acceptingFrom = DateTime.now().add(const Duration(milliseconds: 600));

  String _entry = '';

  bool get _isAccepting => DateTime.now().isAfter(_acceptingFrom);

  void _append(String digit) {
    if (!_isAccepting || _entry.length >= ParentalControlRepository.pinLength) {
      return;
    }
    setState(() => _entry += digit);
    if (_entry.length == ParentalControlRepository.pinLength) {
      Navigator.of(context).pop(_entry);
    }
  }

  void _removeLast() {
    if (!_isAccepting || _entry.isEmpty) {
      return;
    }
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.neonPurple.withValues(alpha: 0.5), width: 2),
      ),
      title: Column(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.neonPurple, size: 34),
          const SizedBox(height: 10),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                ParentalControlRepository.pinLength,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _entry.length
                          ? AppColors.neonPurple
                          : Colors.transparent,
                      border: Border.all(color: AppColors.neonPurple, width: 2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (int digit = 1; digit <= 9; digit++)
                  _PinKey(
                    label: '$digit',
                    autofocus: digit == 1,
                    onActivate: () => _append('$digit'),
                  ),
                _PinKey(
                  label: '0',
                  onActivate: () => _append('0'),
                ),
                _PinKey(
                  icon: Icons.backspace_outlined,
                  glowColor: AppColors.danger,
                  onActivate: _removeLast,
                ),
                _PinKey(
                  icon: Icons.close_rounded,
                  glowColor: AppColors.danger,
                  onActivate: () {
                    if (_isAccepting) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    this.label,
    this.icon,
    required this.onActivate,
    this.glowColor = AppColors.neonCyan,
    this.autofocus = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onActivate;
  final Color glowColor;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return NeonFocusCard(
      width: 74,
      height: 62,
      padding: EdgeInsets.zero,
      borderRadius: 14,
      focusedScale: 1.08,
      unfocusedOpacity: 0.75,
      glowColor: glowColor,
      autofocus: autofocus,
      onActivate: onActivate,
      child: Center(
        child: icon != null
            ? Icon(icon, color: glowColor, size: 24)
            : Text(
                label!,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}
