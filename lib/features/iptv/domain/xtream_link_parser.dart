import '../../profile/data/models/profile_model.dart';

class XtreamCredentials {
  const XtreamCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;

  ProfileModel applyTo(ProfileModel profile) {
    return profile.copyWith(
      type: ProfileType.xtream,
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
  }
}

/// Detects Xtream get.php / player_api links pasted into an M3U field.
abstract final class XtreamLinkParser {
  static ProfileModel resolve(ProfileModel profile) {
    if (profile.type == ProfileType.xtream) {
      return profile;
    }
    return tryParse(profile.m3uUrl)?.applyTo(profile) ?? profile;
  }

  static XtreamCredentials? tryParse(String? raw) {
    final String trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(trimmed.startsWith('http') ? trimmed : 'http://$trimmed');
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final Map<String, String> query = uri.queryParameters.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );
    final String username = (query['username'] ?? query['user'] ?? '').trim();
    final String password = (query['password'] ?? query['pass'] ?? '').trim();
    if (username.isEmpty || password.isEmpty || !_looksLikeXtream(uri, query)) {
      return null;
    }

    final String scheme = uri.scheme.isEmpty ? 'http' : uri.scheme;
    final String port = uri.hasPort ? ':${uri.port}' : '';
    return XtreamCredentials(
      serverUrl: '$scheme://${uri.host}$port',
      username: username,
      password: password,
    );
  }

  static bool _looksLikeXtream(Uri uri, Map<String, String> query) {
    final String path = uri.path.toLowerCase();
    final String type = (query['type'] ?? '').toLowerCase();
    return path.contains('get.php') ||
        path.contains('player_api.php') ||
        path.contains('xmltv.php') ||
        path.contains('playlist') ||
        type == 'm3u' ||
        type == 'm3u_plus' ||
        query.containsKey('output');
  }
}
