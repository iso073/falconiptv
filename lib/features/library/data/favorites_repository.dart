import 'package:hive/hive.dart';

import '../../iptv/data/models/playable_item.dart';

class FavoritesRepository {
  FavoritesRepository(this._box);

  final Box<dynamic> _box;

  String _key(String profileId, PlayableItem item) =>
      '$profileId|${item.kind.name}|${item.id}';

  bool isFavorite(String profileId, PlayableItem item) =>
      _box.containsKey(_key(profileId, item));

  Future<void> toggle(String profileId, PlayableItem item) async {
    final String key = _key(profileId, item);
    if (_box.containsKey(key)) {
      await _box.delete(key);
      return;
    }
    await _box.put(key, <String, dynamic>{
      'profileId': profileId,
      ...item.toMap(),
    });
  }

  List<PlayableItem> list(String profileId) {
    final List<PlayableItem> items = <PlayableItem>[];
    for (final dynamic raw in _box.values) {
      if (raw is! Map) {
        continue;
      }
      if ('${raw['profileId']}' != profileId) {
        continue;
      }
      items.add(PlayableItem.fromMap(raw));
    }
    return items;
  }
}
