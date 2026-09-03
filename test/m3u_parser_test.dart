import 'package:falconiptv/features/iptv/data/models/playable_item.dart';
import 'package:falconiptv/features/iptv/data/parsers/m3u_parser.dart';
import 'package:flutter_test/flutter_test.dart';

const String _playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="trt1.tr" tvg-name="TRT 1" tvg-logo="http://logo.invalid/trt1.png" group-title="Ulusal",TRT 1 HD
http://server.invalid:8080/live/user/pass/1.m3u8
#EXTINF:-1 tvg-logo="http://logo.invalid/spor.png" group-title="Spor",Spor Kanalı
http://server.invalid:8080/live/user/pass/2.ts
#EXTINF:-1,Bilinmeyen Grup
#EXTVLCOPT:network-caching=1000
http://server.invalid:8080/live/user/pass/3.m3u8
#EXTINF:-1 group-title="Spor",Yorumsuz Kanal
''';

void main() {
  test('M3uParser #EXTINF satırlarından kanal ve kategori çıkarır', () {
    final List<PlayableItem> items = M3uParser.parse(_playlist);

    expect(items.length, 3);
    expect(items.first.title, 'TRT 1 HD');
    expect(items.first.category, 'Ulusal');
    expect(items.first.logoUrl, 'http://logo.invalid/trt1.png');
    expect(items.first.streamUrl, 'http://server.invalid:8080/live/user/pass/1.m3u8');

    expect(items[1].streamUrl.endsWith('.ts'), isTrue);
    expect(items[2].category, 'Diğer');
    expect(items[2].streamUrl, 'http://server.invalid:8080/live/user/pass/3.m3u8');
  });

  test('M3uParser kategori listesini Tümü ile başlatır', () {
    final List<String> categories = M3uParser.categoriesOf(M3uParser.parse(_playlist));

    expect(categories.first, 'Tümü');
    expect(categories.contains('Ulusal'), isTrue);
    expect(categories.contains('Spor'), isTrue);
    expect(categories.length, 4);
  });
}
