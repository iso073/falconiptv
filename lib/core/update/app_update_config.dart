import 'dart:io';

/// GitHub Releases kaynağı. Depo herkese açık olmalıdır.
abstract final class AppUpdateConfig {
  static const String githubOwner = 'iso073';
  static const String githubRepo = 'falconiptv';
  static const String apkAssetName = 'falconiptv.apk';

  /// pubspec.yaml `version` ile aynı tutulmalıdır.
  static const String currentName = '1.0.5';
  static const int currentCode = 6;

  static const Duration checkInterval = Duration(hours: 12);

  static String get latestApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static String get latestPageUrl =>
      'https://github.com/$githubOwner/$githubRepo/releases/latest';

  static String apkUrlForTag(String tag) {
    final String safeTag = tag.startsWith('v') || tag.startsWith('V') ? tag : 'v$tag';
    return 'https://github.com/$githubOwner/$githubRepo/releases/download/$safeTag/$apkAssetName';
  }

  static String? tagFromReleaseUrl(String location) {
    final List<String> parts = location.split('/');
    final int tagIndex = parts.lastIndexOf('tag');
    if (tagIndex == -1 || tagIndex + 1 >= parts.length) {
      return null;
    }
    return Uri.decodeComponent(parts[tagIndex + 1].split('?').first);
  }
}

class AppVersionInfo {
  const AppVersionInfo({required this.name, required this.code, this.tag = ''});

  final String name;
  final int code;
  final String tag;

  static const AppVersionInfo current = AppVersionInfo(
    name: AppUpdateConfig.currentName,
    code: AppUpdateConfig.currentCode,
  );

  static AppVersionInfo parse(String raw) {
    final String tag = raw.trim();
    final String trimmed = tag.replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    final List<String> parts = trimmed.split('+');
    final String name = parts.first.trim().isEmpty ? '0.0.0' : parts.first.trim();
    final int? explicitCode = parts.length > 1 ? int.tryParse(parts[1].trim()) : null;
    return AppVersionInfo(
      name: name,
      code: explicitCode ?? _codeFromName(name),
      tag: tag,
    );
  }

  bool isNewerThan(AppVersionInfo other) {
    if (code != other.code) {
      return code > other.code;
    }
    return _compareNames(name, other.name) > 0;
  }

  static int _codeFromName(String name) {
    final List<int> parts = name
        .split('.')
        .map((String part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final int major = parts.isNotEmpty ? parts[0] : 0;
    final int minor = parts.length > 1 ? parts[1] : 0;
    final int patch = parts.length > 2 ? parts[2] : 0;
    return major * 10000 + minor * 100 + patch;
  }

  static int _compareNames(String a, String b) {
    final List<int> left = a.split('.').map((String p) => int.tryParse(p) ?? 0).toList();
    final List<int> right = b.split('.').map((String p) => int.tryParse(p) ?? 0).toList();
    final int length = left.length > right.length ? left.length : right.length;
    for (int i = 0; i < length; i++) {
      final int l = i < left.length ? left[i] : 0;
      final int r = i < right.length ? right[i] : 0;
      if (l != r) {
        return l.compareTo(r);
      }
    }
    return 0;
  }
}

class GithubReleaseInfo {
  const GithubReleaseInfo({
    required this.tag,
    required this.version,
    required this.apkUrl,
    this.notes = '',
    this.apkSize = 0,
  });

  final String tag;
  final AppVersionInfo version;
  final String apkUrl;
  final String notes;
  final int apkSize;

  String get cacheFileName {
    final String safeTag = tag.replaceAll(RegExp(r'[^A-Za-z0-9._+-]'), '_');
    return 'falconiptv-$safeTag.apk';
  }

  bool isReusableCache(File file) {
    return AppUpdateCache.isReusable(file, expectedSize: apkSize);
  }

  static GithubReleaseInfo? fromJson(Map<String, dynamic> json, {String preferredAsset = ''}) {
    final String tag = '${json['tag_name'] ?? json['name'] ?? ''}'.trim();
    if (tag.isEmpty) {
      return null;
    }
    final Object? assetsRaw = json['assets'];
    if (assetsRaw is! List) {
      return null;
    }
    String? url;
    int size = 0;
    for (final Object? asset in assetsRaw) {
      if (asset is! Map) {
        continue;
      }
      final String name = '${asset['name'] ?? ''}'.toLowerCase();
      final String browser = '${asset['browser_download_url'] ?? ''}';
      if (!name.endsWith('.apk') || browser.isEmpty) {
        continue;
      }
      final int assetSize = int.tryParse('${asset['size'] ?? ''}') ?? 0;
      if (preferredAsset.isNotEmpty && name == preferredAsset.toLowerCase()) {
        url = browser;
        size = assetSize;
        break;
      }
      url ??= browser;
      if (url == browser) {
        size = assetSize;
      }
    }
    if (url == null) {
      return null;
    }
    return GithubReleaseInfo(
      tag: tag,
      version: AppVersionInfo.parse(tag),
      apkUrl: url,
      notes: '${json['body'] ?? ''}'.trim(),
      apkSize: size,
    );
  }
}

abstract final class AppUpdateCache {
  static const int minApkBytes = 1024 * 1024;

  static bool isReusable(File file, {int expectedSize = 0}) {
    if (!file.existsSync()) {
      return false;
    }
    final int length = file.lengthSync();
    if (length < minApkBytes) {
      return false;
    }
    if (expectedSize > 0 && length != expectedSize) {
      return false;
    }
    return true;
  }
}
