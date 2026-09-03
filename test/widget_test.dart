import 'package:flutter_test/flutter_test.dart';

import 'package:falconiptv/features/profile/data/models/profile_model.dart';

void main() {
  test('ProfileModel Xtream ve M3U tiplerini ayırır', () {
    final ProfileModel xtream = ProfileModel(
      id: '1',
      profileName: 'Kurumsal Yayın',
      type: ProfileType.xtream,
      serverUrl: 'http://example.invalid',
      username: 'user',
      password: 'pass',
      createdDate: DateTime(2026, 1, 1),
    );
    final ProfileModel m3u = ProfileModel(
      id: '2',
      profileName: 'Oynatma Listesi',
      type: ProfileType.m3u,
      m3uUrl: 'http://example.invalid/playlist.m3u',
      createdDate: DateTime(2026, 1, 1),
    );

    expect(xtream.type, ProfileType.xtream);
    expect(m3u.type, ProfileType.m3u);
    expect(xtream.copyWith(profileName: 'Yeni').profileName, 'Yeni');
  });
}
