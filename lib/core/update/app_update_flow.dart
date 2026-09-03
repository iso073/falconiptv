import 'dart:io';

import 'package:flutter/material.dart';

import '../services/tv_toast_service.dart';
import '../theme/app_colors.dart';
import '../widgets/exit_confirm_dialog.dart';
import 'app_update_config.dart';
import 'app_update_service.dart';

abstract final class AppUpdateFlow {
  static Future<void> check(
    BuildContext context,
    AppUpdateService service, {
    bool force = false,
  }) async {
    if (!force && !service.shouldAutoCheck) {
      return;
    }
    try {
      final GithubReleaseInfo? update = await service.availableUpdate();
      await service.markChecked();
      if (!context.mounted) {
        return;
      }
      if (update == null) {
        if (force) {
          TvToastService.show(
            context,
            'Uygulama güncel. Sürüm ${AppVersionInfo.current.name}',
            type: TvToastType.success,
          );
        }
        return;
      }
      final bool install = await showNeonConfirmDialog(
        context: context,
        title: 'Yeni Sürüm',
        message:
            'Sürüm ${update.version.name} yayımlandı. Şu an ${AppVersionInfo.current.name} yüklü. Güncellemek ister misiniz?',
        cancelLabel: 'Daha sonra',
        confirmLabel: 'Güncelle',
        confirmColor: AppColors.neonCyan,
      );
      if (!install || !context.mounted) {
        return;
      }
      final File? cached = await service.cachedApk(update);
      if (cached != null) {
        if (context.mounted) {
          TvToastService.show(
            context,
            'İndirilmiş paket kullanılıyor. Yeniden indirilmiyor.',
            type: TvToastType.success,
          );
        }
        await _install(context, service, cached);
        return;
      }
      await _downloadAndInstall(context, service, update);
    } catch (_) {
      if (force && context.mounted) {
        TvToastService.show(
          context,
          'Sürüm denetimi yapılamadı. İnternet bağlantınızı kontrol ediniz.',
        );
      }
    }
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    AppUpdateService service,
    GithubReleaseInfo update,
  ) async {
    if (!await service.canInstallPackages()) {
      if (context.mounted) {
        TvToastService.show(
          context,
          'Bilinmeyen uygulamaların yüklenmesine izin veriniz, ardından yeniden deneyiniz.',
        );
      }
      await service.openInstallPermission();
      return;
    }

    final ValueNotifier<double?> progress = ValueNotifier<double?>(null);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.45), width: 2),
          ),
          title: const Text(
            'Güncelleme indiriliyor',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    color: AppColors.neonCyan,
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value == null ? 'Hazırlanıyor…' : '%${(value * 100).clamp(0, 100).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    try {
      final File file = await service.downloadApk(
        update,
        onProgress: (int received, int total) {
          if (total > 0) {
            progress.value = received / total;
          }
        },
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await _install(context, service, file);
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        TvToastService.show(context, 'Güncelleme indirilemedi. Lütfen daha sonra yeniden deneyiniz.');
      }
    } finally {
      progress.dispose();
    }
  }

  static Future<void> _install(
    BuildContext context,
    AppUpdateService service,
    File file,
  ) async {
    if (!await service.canInstallPackages()) {
      if (context.mounted) {
        TvToastService.show(
          context,
          'Bilinmeyen uygulamaların yüklenmesine izin veriniz, ardından yeniden deneyiniz.',
        );
      }
      await service.openInstallPermission();
      return;
    }
    if (!await service.canInstallOverCurrent(file)) {
      if (context.mounted) {
        await showNeonConfirmDialog(
          context: context,
          title: 'Kurulum Engellendi',
          message:
              'Yüklü kopya farklı bir imza ile kurulmuş. Uygulamayı bir kez kaldırıp yeni falconiptv.apk dosyasını yükleyiniz. Sonraki güncellemeler sorunsuz kurulur.',
          cancelLabel: 'Kapat',
          confirmLabel: 'Tamam',
          confirmColor: AppColors.neonCyan,
        );
      }
      return;
    }
    await service.installApk(file);
  }
}
