import 'dart:io';

import 'package:falconiptv/core/update/app_update_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sürüm etiketi kod ve isimden okunur', () {
    expect(AppVersionInfo.parse('v1.2.0+15').name, '1.2.0');
    expect(AppVersionInfo.parse('v1.2.0+15').code, 15);
    expect(AppVersionInfo.parse('1.0.3').code, 10003);
  });

  test('yeni sürüm eski sürümden büyük sayılır', () {
    const AppVersionInfo current = AppVersionInfo(name: '1.0.0', code: 1);
    expect(AppVersionInfo.parse('v1.0.1+2').isNewerThan(current), isTrue);
    expect(AppVersionInfo.parse('v1.0.0+1').isNewerThan(current), isFalse);
  });

  test('GitHub sürüm JSON içinden APK adresi seçilir', () {
    final GithubReleaseInfo? release = GithubReleaseInfo.fromJson(
      <String, dynamic>{
        'tag_name': 'v1.1.0+3',
        'body': 'Hata düzeltmeleri',
        'assets': <Map<String, Object>>[
          <String, Object>{
            'name': 'notes.txt',
            'browser_download_url': 'https://example.com/notes.txt',
          },
          <String, Object>{
            'name': 'falconiptv.apk',
            'browser_download_url': 'https://example.com/falconiptv.apk',
            'size': 55956613,
          },
        ],
      },
      preferredAsset: 'falconiptv.apk',
    );

    expect(release, isNotNull);
    expect(release!.apkUrl, 'https://example.com/falconiptv.apk');
    expect(release.apkSize, 55956613);
    expect(release.cacheFileName, 'falconiptv-v1.1.0+3.apk');
    expect(release.version.isNewerThan(AppVersionInfo.current), isTrue);
  });

  test('indirilmiş APK aynı boyuttaysa yeniden indirilmez', () {
    final Directory dir = Directory.systemTemp.createTempSync('falcon-apk');
    final File file = File('${dir.path}/falconiptv-v1.0.1+2.apk');
    file.writeAsBytesSync(List<int>.filled(AppUpdateCache.minApkBytes, 1));
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });

    expect(AppUpdateCache.isReusable(file, expectedSize: AppUpdateCache.minApkBytes), isTrue);
    expect(AppUpdateCache.isReusable(file, expectedSize: AppUpdateCache.minApkBytes + 10), isFalse);
    expect(AppUpdateCache.isReusable(File('${dir.path}/yok.apk')), isFalse);
  });

  test('GitHub yönlendirme adresinden sürüm etiketi okunur', () {
    expect(
      AppUpdateConfig.tagFromReleaseUrl(
        'https://github.com/iso073/falconiptv/releases/tag/v1.0.1+2',
      ),
      'v1.0.1+2',
    );
  });
}
