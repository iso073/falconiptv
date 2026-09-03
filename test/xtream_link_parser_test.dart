import 'package:falconiptv/features/iptv/domain/xtream_link_parser.dart';
import 'package:falconiptv/features/profile/data/models/profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

ProfileModel _m3u(String url) {
  return ProfileModel(
    id: '1',
    profileName: 'Liste',
    type: ProfileType.m3u,
    m3uUrl: url,
    createdDate: DateTime(2026, 1, 1),
  );
}

void main() {
  test('get.php Xtream bağlantısından sunucu ve giriş bilgisi çıkarılır', () {
    final XtreamCredentials? parsed = XtreamLinkParser.tryParse(
      'http://panel.example:8080/get.php?username=ali&password=gizli&type=m3u_plus&output=ts',
    );

    expect(parsed, isNotNull);
    expect(parsed!.serverUrl, 'http://panel.example:8080');
    expect(parsed.username, 'ali');
    expect(parsed.password, 'gizli');
  });

  test('player_api.php bağlantısı Xtream sayılır', () {
    final XtreamCredentials? parsed = XtreamLinkParser.tryParse(
      'http://host.tv/player_api.php?username=u1&password=p1',
    );

    expect(parsed?.serverUrl, 'http://host.tv');
    expect(parsed?.username, 'u1');
  });

  test('düz M3U adresi Xtream sayılmaz', () {
    expect(
      XtreamLinkParser.tryParse('http://cdn.example.com/playlist.m3u8'),
      isNull,
    );
    expect(
      XtreamLinkParser.tryParse('http://cdn.example.com/list.m3u?token=abc'),
      isNull,
    );
  });

  test('M3U profili Xtream bağlantısıysa canlı API profiline çevrilir', () {
    final ProfileModel resolved = XtreamLinkParser.resolve(
      _m3u('http://dns:25461/get.php?username=demo&password=pass&type=m3u'),
    );

    expect(resolved.type, ProfileType.xtream);
    expect(resolved.serverUrl, 'http://dns:25461');
    expect(resolved.username, 'demo');
    expect(resolved.password, 'pass');
    expect(resolved.profileName, 'Liste');
  });

  test('gerçek M3U profilinin tipi değişmez', () {
    final ProfileModel resolved = XtreamLinkParser.resolve(
      _m3u('https://example.com/channels.m3u'),
    );

    expect(resolved.type, ProfileType.m3u);
    expect(resolved.m3uUrl, 'https://example.com/channels.m3u');
  });
}
