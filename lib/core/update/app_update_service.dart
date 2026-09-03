import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../constants/hive_boxes.dart';
import '../network/iptv_dio_client.dart';
import 'app_update_config.dart';

class AppUpdateService {
  AppUpdateService(this._settingsBox, {Dio? dio}) : _dio = dio ?? IptvDioClient.create();

  final Box<dynamic> _settingsBox;
  final Dio _dio;

  static const MethodChannel _channel = MethodChannel('falconiptv/update');

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
    try {
      return await _fetchFromApi();
    } catch (_) {
      return _fetchFromReleasesPage();
    }
  }

  Future<GithubReleaseInfo?> _fetchFromApi() async {
    final Response<dynamic> response = await _dio.get<dynamic>(AppUpdateConfig.latestApiUrl);
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
    final Object? data = response.data;
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

  Future<GithubReleaseInfo?> _fetchFromReleasesPage() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      AppUpdateConfig.latestPageUrl,
      options: Options(
        followRedirects: false,
        validateStatus: (int? status) =>
            status != null && (status < 400 || status == 301 || status == 302 || status == 303),
      ),
    );
    if (response.statusCode == 404) {
      return null;
    }
    final String location = response.headers.value('location') ?? response.realUri.toString();
    final String? tag = AppUpdateConfig.tagFromReleaseUrl(location);
    if (tag == null || tag.isEmpty) {
      return null;
    }
    final String apkUrl = AppUpdateConfig.apkUrlForTag(tag);
    return GithubReleaseInfo(
      tag: tag,
      version: AppVersionInfo.parse(tag),
      apkUrl: apkUrl,
      apkSize: await _remoteApkSize(apkUrl),
    );
  }

  Future<int> _remoteApkSize(String url) async {
    try {
      final Response<dynamic> response = await _dio.head<dynamic>(
        url,
        options: Options(
          followRedirects: true,
          validateStatus: (int? status) => status != null && status < 400,
        ),
      );
      return int.tryParse(response.headers.value('content-length') ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
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
