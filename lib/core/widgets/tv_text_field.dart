import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../device/form_factor.dart';
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
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late final FocusNode _ownedNode;
  FocusNode get _focusNode => widget.focusNode ?? _ownedNode;
  bool _focused = false;
  bool _editing = false;

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
    final bool hasFocus = _focusNode.hasFocus;
    setState(() {
      _focused = hasFocus;
      if (!hasFocus) {
        _editing = false;
      }
    });
    if (!hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  bool _isActivateKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space;
  }

  void _beginEdit() {
    if (_editing) {
      return;
    }
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _endEdit() {
    if (!_editing) {
      return;
    }
    setState(() => _editing = false);
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (_isActivateKey(event.logicalKey)) {
      if (_editing) {
        return KeyEventResult.ignored;
      }
      _beginEdit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _endEdit();
      FocusScope.of(context).nextFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _endEdit();
      FocusScope.of(context).previousFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bool phone = FormFactor.isPhoneOf(context);
    final bool editing = phone || _editing;
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
        readOnly: phone ? false : !_editing,
        showCursor: editing,
        enableInteractiveSelection: editing,
        obscureText: widget.obscureText,
        keyboardType: editing ? widget.keyboardType : TextInputType.none,
        textInputAction: widget.textInputAction,
        onTap: _beginEdit,
        onChanged: widget.onChanged,
        onEditingComplete: phone
            ? null
            : () {},
        onSubmitted: (String value) {
          if (phone) {
            _focusNode.unfocus();
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          } else {
            _endEdit();
          }
          if (widget.onSubmitted != null) {
            widget.onSubmitted!(value);
            return;
          }
          FocusScope.of(context).nextFocus();
        },
        style: TextStyle(fontSize: phone ? 16 : 20, color: AppColors.textPrimary),
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
