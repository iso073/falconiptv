import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Phone vs 10-foot TV. Screen size is never used.
///
/// Play Store TVs (Sony, TCL, Hisense, Shield, Chromecast, Streamer, …) report
/// Leanback and/or `UI_MODE_TYPE_TELEVISION`. Phones and tablets do not.
/// A high-density 1080p TV can have a logical shortest side under 550 dp; a
/// landscape tablet can be huge. Both would be misclassified by size.
enum DeviceKind { phone, television }

class DeviceSignals {
  const DeviceSignals({
    this.leanback = false,
    this.leanbackOnly = false,
    this.televisionFeature = false,
    this.uiModeTelevision = false,
    this.fireTv = false,
    this.watch = false,
    this.automotive = false,
  });

  final bool leanback;
  final bool leanbackOnly;
  final bool televisionFeature;
  final bool uiModeTelevision;
  final bool fireTv;
  final bool watch;
  final bool automotive;

  static DeviceSignals? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Map<Object?, Object?> map = raw;
    return DeviceSignals(
      leanback: map['leanback'] == true,
      leanbackOnly: map['leanbackOnly'] == true,
      televisionFeature: map['televisionFeature'] == true,
      uiModeTelevision: map['uiModeTelevision'] == true,
      fireTv: map['fireTv'] == true,
      watch: map['watch'] == true,
      automotive: map['automotive'] == true,
    );
  }
}

/// Official platform signals only. Never pass width, height, or density here.
DeviceKind classifyDevice(DeviceSignals signals) {
  if (signals.watch || signals.automotive) {
    return DeviceKind.phone;
  }
  if (signals.leanback ||
      signals.leanbackOnly ||
      signals.televisionFeature ||
      signals.uiModeTelevision ||
      signals.fireTv) {
    return DeviceKind.television;
  }
  return DeviceKind.phone;
}

abstract final class FormFactor {
  static const MethodChannel _channel = MethodChannel('falconiptv/device');

  static bool _isTelevision = false;
  static bool _ready = false;

  static bool get isTelevision => _isTelevision;
  static bool get isPhone => !_isTelevision;
  static bool get isReady => _ready;

  static Future<void> ensureInitialized() async {
    if (_ready) {
      return;
    }
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final Object? raw = await _channel
            .invokeMethod<dynamic>('deviceProfile')
            .timeout(const Duration(milliseconds: 1500));
        final DeviceKind? kind = _kindFromChannel(raw);
        if (kind != null) {
          _isTelevision = kind == DeviceKind.television;
          _ready = true;
          assert(() {
            debugPrint('FormFactor: $kind from $raw');
            return true;
          }());
          return;
        }
      } catch (_) {
        await Future<void>.delayed(Duration(milliseconds: 120 * (attempt + 1)));
      }
    }
  }

  static DeviceKind? _kindFromChannel(Object? raw) {
    if (raw is bool) {
      return raw ? DeviceKind.television : DeviceKind.phone;
    }
    if (raw is Map) {
      final DeviceSignals? signals = DeviceSignals.tryParse(raw);
      if (signals != null &&
          (raw.containsKey('leanback') ||
              raw.containsKey('uiModeTelevision') ||
              raw.containsKey('leanbackOnly') ||
              raw.containsKey('televisionFeature') ||
              raw.containsKey('fireTv'))) {
        return classifyDevice(signals);
      }
      if (raw['isTelevision'] is bool) {
        return raw['isTelevision'] == true ? DeviceKind.television : DeviceKind.phone;
      }
    }
    return null;
  }

  static bool isPhoneOf(BuildContext context) => !isTelevisionOf(context);

  static bool isTelevisionOf(BuildContext context) {
    if (_ready) {
      return _isTelevision;
    }
    // Native profile is not ready yet. Flutter marks Android TV / Google TV as
    // directional; phones stay traditional even with a keyboard or gamepad.
    return MediaQuery.maybeOf(context)?.navigationMode == NavigationMode.directional;
  }
}
