import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../constants/hive_boxes.dart';
import 'app_update_config.dart';

class AppUpdateService {
  AppUpdateService(this._settingsBox, {Dio? dio}) : _dio = dio ?? _createGithubDio();

  final Box<dynamic> _settingsBox;
  final Dio _dio;

  static const MethodChannel _channel = MethodChannel('falconiptv/update');

  static Dio _createGithubDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 15),
        followRedirects: true,
        headers: const <String, String>{
          'User-Agent': 'FalconIPTV',
          'Accept': 'application/vnd.github+json',
        },
      ),
    );
  }

  bool get shouldAutoCheck {
    final Object? raw = _settingsBox.get(HiveBoxes.lastUpdateCheckKey);
    if (raw is! int) {
      return true;
    }
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(raw)) >=
        AppUpdateConfig.checkInterval;
  }

  Future<void> markChecked() {
    return _settingsBox.put(HiveBoxes.lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<GithubReleaseInfo?> fetchLatest() async {
    Object? lastError;
    try {
      final GithubReleaseInfo? fromLatest = await _fetchFromApi(AppUpdateConfig.latestApiUrl);
      if (fromLatest != null) {
        return fromLatest;
      }
    } catch (error) {
      lastError = error;
    }
    try {
      final GithubReleaseInfo? fromList = await _fetchNewestFromList();
      if (fromList != null) {
        return fromList;
      }
    } catch (error) {
      lastError = error;
    }
    try {
      final GithubReleaseInfo? fromPage = await _fetchFromReleasesPage();
      if (fromPage != null) {
        return fromPage;
      }
    } catch (error) {
      lastError = error;
    }
    if (lastError != null) {
      throw lastError;
    }
    return null;
  }

  Future<GithubReleaseInfo?> _fetchFromApi(String url) async {
    final Response<dynamic> response = await _dio.get<dynamic>(url);
    if (response.statusCode == 404) {
      return null;
    }
    if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'GitHub sürüm bilgisi alınamadı.',
      );
    }
    return _releaseFromData(response.data);
  }

  Future<GithubReleaseInfo?> _fetchNewestFromList() async {
    final Response<dynamic> response = await _dio.get<dynamic>(AppUpdateConfig.releasesApiUrl);
    if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: 'GitHub sürüm listesi alınamadı.',
      );
    }
    final Object? data = _decodeData(response.data);
    if (data is! List) {
      return null;
    }
    GithubReleaseInfo? newest;
    for (final Object? item in data) {
      if (item is! Map) {
        continue;
      }
      if (item['draft'] == true || item['prerelease'] == true) {
        continue;
      }
      final GithubReleaseInfo? release = GithubReleaseInfo.fromJson(
        Map<String, dynamic>.from(item),
        preferredAsset: AppUpdateConfig.apkAssetName,
      );
      if (release == null) {
        continue;
      }
      if (newest == null || release.version.isNewerThan(newest.version)) {
        newest = release;
      }
    }
    return newest;
  }

  Future<GithubReleaseInfo?> _fetchFromReleasesPage() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      AppUpdateConfig.latestPageUrl,
      options: Options(
        headers: const <String, String>{
          'User-Agent': 'FalconIPTV',
          'Accept': 'text/html',
        },
        followRedirects: true,
        validateStatus: (int? status) =>
            status != null && (status < 400 || status == 301 || status == 302 || status == 303),
      ),
    );
    if (response.statusCode == 404) {
      return null;
    }
    final String location = response.realUri.toString();
    String? tag = AppUpdateConfig.tagFromReleaseUrl(location);
    tag ??= AppUpdateConfig.tagFromReleaseUrl(response.headers.value('location') ?? '');
    if (tag == null || tag.isEmpty) {
      final Object? body = response.data;
      if (body is String) {
        tag = AppUpdateConfig.tagFromHtml(body);
      }
    }
    if (tag == null || tag.isEmpty) {
      return null;
    }
    final String apkUrl = AppUpdateConfig.apkUrlForTag(tag);
    return GithubReleaseInfo(
      tag: tag,
      version: AppVersionInfo.parse(tag),
      apkUrl: apkUrl,
    );
  }

  GithubReleaseInfo? _releaseFromData(Object? raw) {
    final Object? data = _decodeData(raw);
    if (data is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(data);
    if ('${json['message']}' == 'Not Found') {
      return null;
    }
    return GithubReleaseInfo.fromJson(
      json,
      preferredAsset: AppUpdateConfig.apkAssetName,
    );
  }

  Object? _decodeData(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  Future<GithubReleaseInfo?> availableUpdate() async {
    final GithubReleaseInfo? latest = await fetchLatest();
    if (latest == null || !latest.version.isNewerThan(AppVersionInfo.current)) {
      return null;
    }
    return latest;
  }

  Future<File?> cachedApk(GithubReleaseInfo release) async {
    final File file = await _apkFile(release);
    if (release.isReusableCache(file)) {
      return file;
    }
    return null;
  }

  Future<File> downloadApk(
    GithubReleaseInfo release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final File? existing = await cachedApk(release);
    if (existing != null) {
      return existing;
    }

    final File file = await _apkFile(release);
    if (file.existsSync()) {
      file.deleteSync();
    }
    await _dio.download(
      release.apkUrl,
      file.path,
      onReceiveProgress: onProgress,
      options: Options(
        headers: const <String, String>{
          'User-Agent': 'FalconIPTV',
          'Accept': '*/*',
        },
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 4),
      ),
    );
    return file;
  }

  Future<File> _apkFile(GithubReleaseInfo release) async {
    final String cacheDir = await _channel.invokeMethod<String>('getCacheDir') ??
        Directory.systemTemp.path;
    final Directory folder = Directory('$cacheDir/updates');
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }
    return File('${folder.path}/${release.cacheFileName}');
  }

  Future<bool> canInstallOverCurrent(File file) async {
    try {
      return await _channel.invokeMethod<bool>('canInstallOverCurrent', file.path) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> canInstallPackages() async {
    return await _channel.invokeMethod<bool>('canInstall') ?? false;
  }

  Future<void> openInstallPermission() {
    return _channel.invokeMethod<void>('openInstallPermission');
  }

  Future<void> installApk(File file) {
    return _channel.invokeMethod<void>('installApk', file.path);
  }
}
