import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/hive_boxes.dart';

class SportModeRepository {
  SportModeRepository(this._settingsBox);

  final Box<dynamic> _settingsBox;

  bool get enabled {
    final Object? raw = _settingsBox.get(HiveBoxes.sportModeKey, defaultValue: false);
    return raw == true;
  }

  Future<void> setEnabled(bool value) {
    return _settingsBox.put(HiveBoxes.sportModeKey, value);
  }
}
