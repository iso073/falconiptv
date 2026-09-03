import 'package:hive_flutter/hive_flutter.dart';

import 'hive_boxes.dart';

abstract final class HiveBootstrap {
  static Future<void> openAll() async {
    await _openDynamic(HiveBoxes.settings);
    await _openDynamic(HiveBoxes.favorites);
    await _openDynamic(HiveBoxes.watchProgress);
  }

  static Future<void> _openDynamic(String name) async {
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox<dynamic>(name);
    }
  }
}
