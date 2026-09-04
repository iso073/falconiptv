import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class NeonFocusCard extends StatefulWidget {
  const NeonFocusCard({
    super.key,
    required this.child,
    this.onActivate,
    this.onLongPress,
    this.glowColor = AppColors.neonCyan,
    this.autofocus = false,
    this.focusNode,
    this.width,
    this.height,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.all(18),
    this.unfocusedOpacity = 0.6,
    this.focusedScale = 1.12,
  });

  final Widget child;
  final VoidCallback? onActivate;
  final VoidCallback? onLongPress;
  final Color glowColor;
  final bool autofocus;
  final FocusNode? focusNode;
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double unfocusedOpacity;
  final double focusedScale;

  @override
  State<NeonFocusCard> createState() => _NeonFocusCardState();
}

class _NeonFocusCardState extends State<NeonFocusCard> {
  static const Duration _longPressThreshold = Duration(milliseconds: 500);

  // Some Android TV remotes emit repeated down/up pairs instead of key repeat
  // events while the D-Pad center stays pressed, so a key up is only treated as
  // a real release when no new key down arrives within this window.
  static const Duration _releaseGrace = Duration(milliseconds: 180);

  late final FocusNode _ownedNode;
  FocusNode get _focusNode => widget.focusNode ?? _ownedNode;
  bool _focused = false;
  Timer? _holdTimer;
  Timer? _releaseTimer;
  bool _pressing = false;
  bool _longPressFired = false;

  @override
  void initState() {
    super.initState();
    _ownedNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant NeonFocusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChange);
      (widget.focusNode ?? _ownedNode).addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _resetPress();
    _focusNode.removeListener(_handleFocusChange);
    _ownedNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final bool hasFocus = _focusNode.hasFocus;
    if (hasFocus != _focused) {
      setState(() => _focused = hasFocus);
    }
    if (!hasFocus) {
      _resetPress();
    }
  }

  void _resetPress() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _releaseTimer?.cancel();
    _releaseTimer = null;
    _pressing = false;
    _longPressFired = false;
  }

  bool _isActivateKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space;
  }

  void _handleKeyDown() {
    _releaseTimer?.cancel();
    _releaseTimer = null;
    if (_pressing) {
      return;
    }
    _pressing = true;
    _longPressFired = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(_longPressThreshold, () {
      if (!_pressing || _longPressFired) {
        return;
      }
      _longPressFired = true;
      widget.onLongPress?.call();
    });
  }

  void _handleKeyUp() {
    if (!_pressing) {
      return;
    }
    _releaseTimer?.cancel();
    _releaseTimer = Timer(_releaseGrace, () {
      final bool wasLongPress = _longPressFired;
      _resetPress();
      if (!wasLongPress) {
        widget.onActivate?.call();
      }
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.delete && widget.onLongPress != null) {
      if (event is KeyDownEvent) {
        widget.onLongPress!.call();
      }
      return KeyEventResult.handled;
    }

    if (!_isActivateKey(key)) {
      return KeyEventResult.ignored;
    }

    if (widget.onLongPress == null) {
      if (event is KeyDownEvent) {
        widget.onActivate?.call();
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      _handleKeyDown();
    } else if (event is KeyUpEvent) {
      _handleKeyUp();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKeyEvent,
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
          widget.onActivate?.call();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _focusNode.requestFocus();
                widget.onLongPress!.call();
              },
        child: AnimatedScale(
          scale: _focused ? widget.focusedScale : 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _focused ? 1 : widget.unfocusedOpacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: _focused ? widget.glowColor : AppColors.glassBorder,
                  width: 3,
                ),
                boxShadow: _focused
                    ? [
                        BoxShadow(
                          color: widget.glowColor.withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: 0,
                          offset: Offset.zero,
                        ),
                      ]
                    : const [],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
