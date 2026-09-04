import 'package:falconiptv/features/iptv/data/models/playable_item.dart';
import 'package:falconiptv/features/iptv/data/models/series_details.dart';
import 'package:flutter_test/flutter_test.dart';

PlayableItem _episode(String id) {
  return PlayableItem(
    id: id,
    title: id,
    category: 'Dizi',
    streamUrl: 'http://server.invalid/$id',
    kind: PlayableKind.series,
    seriesId: 'show',
  );
}

void main() {
  test('dizi bölümleri sezon sırasıyla tek liste olur', () {
    final SeriesDetails details = SeriesDetails(
      series: _episode('show'),
      seasons: <SeriesSeason>[
        SeriesSeason(id: '1', title: 'Sezon 1', episodes: <PlayableItem>[_episode('s1e1'), _episode('s1e2')]),
        SeriesSeason(id: '2', title: 'Sezon 2', episodes: <PlayableItem>[_episode('s2e1')]),
      ],
    );

    expect(details.allEpisodes.map((PlayableItem item) => item.id), <String>['s1e1', 's1e2', 's2e1']);
    expect(details.episodeOffset(0, 1), 1);
    expect(details.episodeOffset(1, 0), 2);
  });
}
