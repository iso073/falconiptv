import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvBackScope extends StatefulWidget {
  const TvBackScope({
    super.key,
    required this.onBack,
    required this.child,
  });

  final Future<void> Function() onBack;
  final Widget child;

  @visibleForTesting
  static void resetBackGuard() => _TvBackScopeState._lastHandledAtMs = 0;

  @override
  State<TvBackScope> createState() => _TvBackScopeState();
}

class _TvBackScopeState extends State<TvBackScope> {
  // Android TV delivers a single back press both as a key event and through the
  // activity back channel. The duplicate can reach a different scope once the
  // top route is gone, so the guard is shared by every scope in the app.
  static const int _debounceMs = 500;
  static int _lastHandledAtMs = 0;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    super.dispose();
  }

  bool _isCurrentRoute() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    return route != null && route.isCurrent;
  }

  bool _isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool _onHardwareKey(KeyEvent event) {
    if (!_isBackKey(event.logicalKey)) {
      return false;
    }
    if (event is! KeyDownEvent) {
      // Swallow the matching key up so it cannot reach focused widgets.
      return true;
    }
    if (!mounted || !_isCurrentRoute()) {
      return false;
    }
    if (_busy || _isDuplicatePress()) {
      return true;
    }
    _invokeBack();
    return true;
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  static bool _isDuplicatePress() => _nowMs() - _lastHandledAtMs < _debounceMs;

  Future<void> _invokeBack() async {
    if (_busy || _isDuplicatePress()) {
      return;
    }
    _busy = true;
    _lastHandledAtMs = _nowMs();
    // Android reports back through the pop channel while the navigator is
    // still processing it, so the handler must not navigate synchronously.
    await Future<void>.delayed(Duration.zero);
    try {
      if (mounted) {
        await widget.onBack();
      }
    } finally {
      _lastHandledAtMs = _nowMs();
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) {
          return;
        }
        await _invokeBack();
      },
      child: widget.child,
    );
  }
}
