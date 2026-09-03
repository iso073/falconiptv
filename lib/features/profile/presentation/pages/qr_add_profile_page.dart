import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/services/tv_toast_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../iptv/data/repositories/m3u_repository.dart';
import '../../data/remote_profile_draft.dart';
import '../../data/remote_profile_server.dart';
import '../cubit/profile_cubit.dart';

class QrAddProfilePage extends StatefulWidget {
  const QrAddProfilePage({super.key});

  @override
  State<QrAddProfilePage> createState() => _QrAddProfilePageState();
}

class _QrAddProfilePageState extends State<QrAddProfilePage> {
  RemoteProfileSession? _session;
  String? _error;
  String _status = 'Telefon bağlantısı bekleniyor.';
  bool _busy = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_session?.stop());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _status = 'Yerel bağlantı hazırlanıyor.';
      _saved = false;
    });
    try {
      final RemoteProfileSession session = await RemoteProfileServer.start(onSubmit: _onSubmit);
      if (!mounted) {
        await session.stop();
        return;
      }
      setState(() {
        _session = session;
        _status = 'Telefon bağlantısı bekleniyor.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error');
      }
    }
  }

  Future<String?> _onSubmit(RemoteProfileDraft draft) async {
    if (!mounted) {
      return 'Televizyon hazır değil. QR ekranını yeniden açınız.';
    }
    if (_busy) {
      return 'Başka bir gönderim işleniyor. Lütfen bekleyiniz.';
    }
    _busy = true;
    if (mounted) {
      setState(() => _status = 'Profil alındı, bağlantı doğrulanıyor.');
    }
    final profile = draft.toProfile();
    try {
      await context.read<IptvCatalogRepository>().validate(profile);
      if (!mounted) {
        return 'İşlem iptal edildi.';
      }
      await context.read<ProfileCubit>().addProfile(profile);
      if (!mounted) {
        return 'İşlem iptal edildi.';
      }
      if (context.read<ProfileCubit>().state is ProfileError) {
        return 'Profil kaydı oluşturulamadı.';
      }
      setState(() {
        _saved = true;
        _status = '"${profile.profileName}" profili kaydedildi.';
      });
      TvToastService.show(
        context,
        'Profil telefondan kaydedildi.',
        type: TvToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return null;
    } on IptvDataException catch (error) {
      if (mounted) {
        setState(() => _status = 'Telefon bağlantısı bekleniyor.');
      }
      return error.message;
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Telefon bağlantısı bekleniyor.');
      }
      return 'Sunucuya bağlanılamadı. Lütfen adres ve internet bağlantınızı kontrol ediniz.';
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Uri? uri = _session?.uri;
    return TvBackScope(
      onBack: () => popToPreviousPage(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.ambientGlow),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
              child: Column(
                children: [
                  GlassmorphismBar(
                    child: Row(
                      children: [
                        NeonFocusCard(
                          autofocus: true,
                          width: 56,
                          height: 56,
                          padding: EdgeInsets.zero,
                          focusedScale: 1.08,
                          onActivate: () => Navigator.of(context).maybePop(),
                          child: const Center(child: Icon(Icons.arrow_back_rounded)),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Telefondan Profil Ekle',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _error != null
                        ? Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 20, height: 1.4),
                                  ),
                                  const SizedBox(height: 20),
                                  NeonFocusCard(
                                    autofocus: true,
                                    onActivate: _start,
                                    child: const Text(
                                      'Yeniden Dene',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: uri == null
                                      ? const SizedBox(
                                          width: 240,
                                          height: 240,
                                          child: Center(
                                            child: CircularProgressIndicator(color: AppColors.neonCyan),
                                          ),
                                        )
                                      : QrImageView(
                                          data: uri.toString(),
                                          size: 240,
                                          backgroundColor: Colors.white,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 28),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Telefonunuzun kamerası ile bu karekodu okutunuz.',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.3),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Açılan sayfadan Xtream Codes veya M3U bilgilerini giriniz. Telefon ile televizyon aynı kablosuz ağda olmalıdır.',
                                      style: TextStyle(fontSize: 17, color: AppColors.textSecondary, height: 1.4),
                                    ),
                                    const SizedBox(height: 20),
                                    if (uri != null) ...[
                                      SelectableText(
                                        uri.toString(),
                                        style: const TextStyle(
                                          color: AppColors.neonCyan,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Kod: ${_session!.token}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 16,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    Text(
                                      _status,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: _saved ? AppColors.success : AppColors.neonPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
