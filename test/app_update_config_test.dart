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
        'assets': <Map<String, String>>[
          <String, String>{
            'name': 'notes.txt',
            'browser_download_url': 'https://example.com/notes.txt',
          },
          <String, String>{
            'name': 'falconiptv.apk',
            'browser_download_url': 'https://example.com/falconiptv.apk',
          },
        ],
      },
      preferredAsset: 'falconiptv.apk',
    );

    expect(release, isNotNull);
    expect(release!.apkUrl, 'https://example.com/falconiptv.apk');
    expect(release.version.isNewerThan(AppVersionInfo.current), isTrue);
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
