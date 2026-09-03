import 'package:falconiptv/features/player/data/hls_track_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HLS AUDIO ve SUBTITLES parçalarını ayırır', () {
    const String source = '''
#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",LANGUAGE="tur",NAME="Türkçe",DEFAULT=YES
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",LANGUAGE="eng",NAME="English",URI="audio_en.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",LANGUAGE="eng",NAME="English",URI="subs.vtt"
#EXT-X-STREAM-INF:BANDWIDTH=2000000
index.m3u8
''';
    final List<MediaTrack> tracks = HlsTrackParser.parse(source);
    expect(tracks.where((MediaTrack t) => t.kind == MediaTrackKind.audio).length, 2);
    expect(tracks.where((MediaTrack t) => t.kind == MediaTrackKind.subtitle).length, 1);
    expect(tracks.last.url, 'subs.vtt');
  });
}
