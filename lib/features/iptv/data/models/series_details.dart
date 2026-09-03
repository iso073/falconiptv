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
