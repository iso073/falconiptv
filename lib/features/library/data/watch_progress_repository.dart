import 'package:hive/hive.dart';

import '../../iptv/data/models/playable_item.dart';
import '../../settings/domain/adult_content_policy.dart';

class WatchProgress {
  const WatchProgress({
    required this.item,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  final PlayableItem item;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  double get fraction {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool get isCompleted => fraction >= 0.92;

  bool get canResume => position.inSeconds >= 10 && !isCompleted;
}

class WatchProgressRepository {
  WatchProgressRepository(this._box);

  final Box<dynamic> _box;

  String _key(String profileId, PlayableItem item) =>
      '$profileId|${item.kind.name}|${item.id}';

  Future<void> save({
    required String profileId,
    required PlayableItem item,
    required Duration position,
    required Duration duration,
  }) async {
    if (duration.inSeconds < 30) {
      return;
    }
    if (position.inSeconds < 10) {
      await _box.delete(_key(profileId, item));
      return;
    }
    await _box.put(_key(profileId, item), <String, dynamic>{
      'profileId': profileId,
      'positionMs': position.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      ...item.toMap(),
    });
  }

  WatchProgress? get(String profileId, PlayableItem item) {
    final dynamic raw = _box.get(_key(profileId, item));
    return _parse(raw);
  }

  List<WatchProgress> continueWatching(String profileId) {
    final List<WatchProgress> items = <WatchProgress>[];
    for (final dynamic raw in _box.values) {
      final WatchProgress? progress = _parse(raw);
      if (progress == null || '${(raw as Map)['profileId']}' != profileId) {
        continue;
      }
      if (progress.canResume &&
          !AdultContentPolicy.isAdultContent(
            category: progress.item.category,
            title: progress.item.title,
            subtitle: progress.item.subtitle,
          )) {
        items.add(progress);
      }
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items.take(12).toList();
  }

  WatchProgress? _parse(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    return WatchProgress(
      item: PlayableItem.fromMap(raw),
      position: Duration(milliseconds: (raw['positionMs'] as int?) ?? 0),
      duration: Duration(milliseconds: (raw['durationMs'] as int?) ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['updatedAt'] as int?) ?? 0,
      ),
    );
  }
}
