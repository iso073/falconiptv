enum PlayableKind { live, vod, series }

class PlayableItem {
  const PlayableItem({
    required this.id,
    required this.title,
    required this.category,
    required this.streamUrl,
    this.subtitle = '',
    this.logoUrl,
    this.kind = PlayableKind.live,
    this.addedAt,
    this.seriesId,
  });

  final String id;
  final String title;
  final String category;
  final String streamUrl;
  final String subtitle;
  final String? logoUrl;
  final PlayableKind kind;
  final DateTime? addedAt;
  final String? seriesId;

  bool get isSeriesShell => kind == PlayableKind.series && streamUrl.isEmpty;

  PlayableItem copyWith({
    String? id,
    String? title,
    String? category,
    String? streamUrl,
    String? subtitle,
    String? logoUrl,
    PlayableKind? kind,
    DateTime? addedAt,
    String? seriesId,
  }) {
    return PlayableItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      streamUrl: streamUrl ?? this.streamUrl,
      subtitle: subtitle ?? this.subtitle,
      logoUrl: logoUrl ?? this.logoUrl,
      kind: kind ?? this.kind,
      addedAt: addedAt ?? this.addedAt,
      seriesId: seriesId ?? this.seriesId,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'category': category,
      'streamUrl': streamUrl,
      'subtitle': subtitle,
      'logoUrl': logoUrl,
      'kind': kind.name,
      'addedAt': addedAt?.millisecondsSinceEpoch,
      'seriesId': seriesId,
    };
  }

  static PlayableItem fromMap(Map<dynamic, dynamic> map) {
    return PlayableItem(
      id: '${map['id'] ?? ''}',
      title: '${map['title'] ?? ''}',
      category: '${map['category'] ?? ''}',
      streamUrl: '${map['streamUrl'] ?? ''}',
      subtitle: '${map['subtitle'] ?? ''}',
      logoUrl: map['logoUrl'] as String?,
      kind: PlayableKind.values.firstWhere(
        (PlayableKind value) => value.name == map['kind'],
        orElse: () => PlayableKind.live,
      ),
      addedAt: map['addedAt'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int)
          : null,
      seriesId: map['seriesId'] as String?,
    );
  }
}

class EpgListing {
  const EpgListing({
    required this.channelName,
    required this.title,
    required this.timeRange,
    required this.category,
  });

  final String channelName;
  final String title;
  final String timeRange;
  final String category;
}

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.categories,
    required this.items,
    this.epg = const <EpgListing>[],
  });

  final List<String> categories;
  final List<PlayableItem> items;
  final List<EpgListing> epg;
}
