import 'package:falconiptv/features/profile/data/models/profile_model.dart';
import 'package:falconiptv/features/profile/data/remote_profile_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Xtream bilgisi JSON gövdesinden okunur', () {
    final RemoteProfileDraft draft = RemoteProfileDraft.parse(
      '{"token":"ABC123","type":"xtream","profileName":"Ev","serverUrl":"http://host:8080","username":"user","password":"pass"}',
      expectedToken: 'ABC123',
    );

    expect(draft.type, ProfileType.xtream);
    expect(draft.profileName, 'Ev');
    expect(draft.serverUrl, 'http://host:8080');
    expect(draft.toProfile().username, 'user');
  });

  test('M3U bağlantısı form gövdesinden okunur', () {
    final RemoteProfileDraft draft = RemoteProfileDraft.parse(
      'token=ABC123&type=m3u&profileName=Liste&m3uUrl=http%3A%2F%2Fhost%2Flist.m3u',
      expectedToken: 'ABC123',
    );

    expect(draft.type, ProfileType.m3u);
    expect(draft.m3uUrl, 'http://host/list.m3u');
  });

  test('yanlış kod reddedilir', () {
    expect(
      () => RemoteProfileDraft.parse(
        '{"token":"WRONG","type":"m3u","profileName":"A","m3uUrl":"http://x"}',
        expectedToken: 'ABC123',
      ),
      throwsFormatException,
    );
  });
}
