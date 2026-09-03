import 'dart:convert';

import 'models/profile_model.dart';

class RemoteProfileDraft {
  const RemoteProfileDraft({
    required this.token,
    required this.type,
    required this.profileName,
    this.serverUrl,
    this.username,
    this.password,
    this.m3uUrl,
  });

  final String token;
  final ProfileType type;
  final String profileName;
  final String? serverUrl;
  final String? username;
  final String? password;
  final String? m3uUrl;

  static RemoteProfileDraft parse(String body, {required String expectedToken}) {
    final Map<String, String> fields = _decode(body);
    final String token = (fields['token'] ?? '').trim();
    if (token.isEmpty || token != expectedToken) {
      throw const FormatException('Bağlantı kodu geçersiz veya süresi dolmuş.');
    }

    final String profileName = (fields['profileName'] ?? '').trim();
    if (profileName.isEmpty) {
      throw const FormatException('Lütfen profil adını giriniz.');
    }

    final String typeName = (fields['type'] ?? 'xtream').trim().toLowerCase();
    if (typeName == 'm3u') {
      final String m3uUrl = (fields['m3uUrl'] ?? '').trim();
      if (m3uUrl.isEmpty) {
        throw const FormatException('Lütfen M3U oynatma listesi bağlantısını giriniz.');
      }
      return RemoteProfileDraft(
        token: token,
        type: ProfileType.m3u,
        profileName: profileName,
        m3uUrl: m3uUrl,
      );
    }

    final String serverUrl = (fields['serverUrl'] ?? '').trim();
    final String username = (fields['username'] ?? '').trim();
    final String password = (fields['password'] ?? '').trim();
    if (serverUrl.isEmpty || username.isEmpty || password.isEmpty) {
      throw const FormatException(
        'Lütfen Xtream Codes için sunucu, kullanıcı adı ve şifreyi giriniz.',
      );
    }
    return RemoteProfileDraft(
      token: token,
      type: ProfileType.xtream,
      profileName: profileName,
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }

  ProfileModel toProfile() {
    return ProfileModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      profileName: profileName,
      type: type,
      serverUrl: serverUrl,
      username: username,
      password: password,
      m3uUrl: m3uUrl,
      createdDate: DateTime.now(),
    );
  }

  static Map<String, String> _decode(String body) {
    final String trimmed = body.trim();
    if (trimmed.startsWith('{')) {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        throw const FormatException('Gönderilen bilgiler okunamadı.');
      }
      return decoded.map(
        (key, value) => MapEntry('$key', value == null ? '' : '$value'),
      );
    }
    return Uri.splitQueryString(trimmed, encoding: utf8);
  }
}
