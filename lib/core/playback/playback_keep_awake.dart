import 'package:flutter/services.dart';

/// Keeps the TV screen on and resets the system idle timer while a stream plays.
abstract final class PlaybackKeepAwake {
  static const MethodChannel _channel = MethodChannel('falconiptv/display');

  static Future<void> enable() => _set(true);

  static Future<void> disable() => _set(false);

  static Future<void> _set(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', enabled);
    } catch (_) {
      // Tests and desktop shells have no Android display channel.
    }
  }
}
