import 'playable_item.dart';

class SeriesSeason {
  const SeriesSeason({required this.id, required this.title, required this.episodes});

  final String id;
  final String title;
  final List<PlayableItem> episodes;
}

class SeriesDetails {
  const SeriesDetails({required this.series, required this.seasons});

  final PlayableItem series;
  final List<SeriesSeason> seasons;

  List<PlayableItem> get allEpisodes {
    return <PlayableItem>[
      for (final SeriesSeason season in seasons) ...season.episodes,
    ];
  }

  int episodeOffset(int seasonIndex, int episodeIndex) {
    int offset = 0;
    final int lastSeason = seasonIndex.clamp(0, seasons.length);
    for (int i = 0; i < lastSeason && i < seasons.length; i++) {
      offset += seasons[i].episodes.length;
    }
    return offset + episodeIndex;
  }
}

class StreamSubtitle {
  const StreamSubtitle({required this.label, required this.url});

  final String label;
  final String url;
}

class XtreamAccountStatus {
  const XtreamAccountStatus({
    required this.active,
    required this.statusLabel,
    this.expiryLabel,
  });

  final bool active;
  final String statusLabel;
  final String? expiryLabel;
}
