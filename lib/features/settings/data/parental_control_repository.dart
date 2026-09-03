import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/hive_boxes.dart';

class ParentalControlRepository {
  ParentalControlRepository(this._settingsBox);

  static const String defaultPin = '0000';
  static const int pinLength = 4;

  final Box<dynamic> _settingsBox;

  /// Cleared on every app start, so the PIN is requested once per session.
  bool _unlockedForSession = false;

  bool get isProtectionEnabled =>
      _settingsBox.get(HiveBoxes.adultProtectionKey, defaultValue: true) as bool;

  String get pin =>
      '${_settingsBox.get(HiveBoxes.adultPinKey, defaultValue: defaultPin)}';

  bool get isUnlocked => !isProtectionEnabled || _unlockedForSession;

  bool verifyPin(String value) => value == pin;

  void unlockSession() => _unlockedForSession = true;

  void lockSession() => _unlockedForSession = false;

  Future<void> setPin(String value) async {
    await _settingsBox.put(HiveBoxes.adultPinKey, value);
  }

  Future<void> setProtectionEnabled(bool enabled) async {
    await _settingsBox.put(HiveBoxes.adultProtectionKey, enabled);
    if (!enabled) {
      _unlockedForSession = false;
    }
  }
}
