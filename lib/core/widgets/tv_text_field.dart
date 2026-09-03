import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofocus = false,
    this.focusNode,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late final FocusNode _ownedNode;
  FocusNode get _focusNode => widget.focusNode ?? _ownedNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _ownedNode = FocusNode(debugLabel: widget.label);
    _focusNode.onKeyEvent = _onKey;
    _focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focusNode.onKeyEvent = null;
    _focusNode.removeListener(_onFocus);
    _ownedNode.dispose();
    super.dispose();
  }

  void _onFocus() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      FocusScope.of(context).nextFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      FocusScope.of(context).previousFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.neonCyan.withValues(alpha: 0.28),
                  blurRadius: 18,
                ),
              ]
            : const [],
      ),
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onEditingComplete: () {},
        onSubmitted: widget.onSubmitted ??
            (_) {
              FocusScope.of(context).nextFocus();
            },
        style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
        cursorColor: AppColors.neonCyan,
        decoration: InputDecoration(
          labelText: widget.label,
          filled: true,
          fillColor: AppColors.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.glassBorder, width: 1.6),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.neonCyan, width: 2.6),
          ),
        ),
      ),
    );
  }
}
