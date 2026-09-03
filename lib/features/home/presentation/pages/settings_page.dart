import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/tv_toast_service.dart';
import '../../../../core/update/app_update_config.dart';
import '../../../../core/update/app_update_flow.dart';
import '../../../../core/update/app_update_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/falcon_logo.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/pages/profile_selection_page.dart';
import '../../../settings/data/parental_control_repository.dart';
import '../../../settings/presentation/widgets/pin_entry_dialog.dart';
import '../cubit/connection_cubit.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ParentalControlRepository get _parental => context.read<ParentalControlRepository>();

  Future<bool> _verifyCurrentPin() async {
    final String? entered = await showPinEntryDialog(
      context: context,
      title: 'Mevcut Şifre',
      message: 'İşleme devam etmek için geçerli erişim şifresini giriniz.',
    );
    if (entered == null || !mounted) {
      return false;
    }
    if (!_parental.verifyPin(entered)) {
      TvToastService.show(context, 'Girilen şifre hatalıdır.');
      return false;
    }
    return true;
  }

  Future<void> _changePin() async {
    if (!await _verifyCurrentPin() || !mounted) {
      return;
    }

    final String? newPin = await showPinEntryDialog(
      context: context,
      title: 'Yeni Şifre',
      message: 'Yetişkin içerik için yeni 4 haneli şifreyi giriniz.',
    );
    if (newPin == null || !mounted) {
      return;
    }

    final String? confirmPin = await showPinEntryDialog(
      context: context,
      title: 'Şifreyi Onaylayınız',
      message: 'Yeni şifreyi tekrar giriniz.',
    );
    if (confirmPin == null || !mounted) {
      return;
    }
    if (newPin != confirmPin) {
      TvToastService.show(context, 'Şifreler birbiriyle uyuşmamaktadır.');
      return;
    }

    await _parental.setPin(newPin);
    if (!mounted) {
      return;
    }
    setState(() {});
    TvToastService.show(
      context,
      'Erişim şifresi güncellendi.',
      type: TvToastType.success,
    );
  }

  Future<void> _toggleProtection() async {
    final bool enabled = _parental.isProtectionEnabled;
    if (!await _verifyCurrentPin() || !mounted) {
      return;
    }
    await _parental.setProtectionEnabled(!enabled);
    if (!mounted) {
      return;
    }
    setState(() {});
    TvToastService.show(
      context,
      enabled
          ? 'Yetişkin içerik koruması devre dışı bırakıldı.'
          : 'Yetişkin içerik koruması etkinleştirildi.',
      type: TvToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvBackScope(
      onBack: () => popToPreviousPage(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.ambientGlow),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassmorphismBar(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                            'Sistem Ayarları',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: BlocBuilder<ProfileCubit, ProfileState>(
                      builder: (context, state) {
                        final ProfileModel? profile =
                            state is ProfileLoaded ? state.activeProfile : null;
                        return ListView(
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          children: [
                            _SettingsListCard(
                              glowColor: AppColors.neonCyan,
                              onActivate: () {
                                final ProfileModel? profile = state is ProfileLoaded
                                    ? state.activeProfile
                                    : null;
                                context.read<ConnectionCubit>().refresh(profile);
                              },
                              child: BlocBuilder<ConnectionCubit, ConnectionSnapshot>(
                                builder: (context, snapshot) {
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.wifi_tethering,
                                      color: AppColors.neonCyan,
                                      size: 32,
                                    ),
                                    title: const Text(
                                      'Bağlantı Durumu',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text('${snapshot.title} • ${snapshot.detail}'),
                                  );
                                },
                              ),
                            ),
                            _SettingsListCard(
                              glowColor: AppColors.neonCyan,
                              onActivate: () {},
                              child: ListTile(
                                leading: const Icon(
                                  Icons.person_outline,
                                  color: AppColors.neonCyan,
                                  size: 32,
                                ),
                                title: const Text(
                                  'Aktif Oturum',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  profile?.profileName ?? 'Aktif profil atanmadı',
                                ),
                              ),
                            ),
                            _SettingsListCard(
                              glowColor: AppColors.neonCyan,
                              onActivate: () {},
                              child: ListTile(
                                leading: const Icon(
                                  Icons.dns_outlined,
                                  color: AppColors.neonCyan,
                                  size: 32,
                                ),
                                title: const Text(
                                  'Bağlantı Türü',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(_connectionSummary(profile)),
                              ),
                            ),
                            _SettingsListCard(
                              glowColor: AppColors.neonPurple,
                              onActivate: _toggleProtection,
                              child: ListTile(
                                leading: const Icon(
                                  Icons.shield_outlined,
                                  color: AppColors.neonPurple,
                                  size: 32,
                                ),
                                title: const Text(
                                  'Yetişkin İçerik Koruması',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  _parental.isProtectionEnabled
                                      ? 'Etkin • Yetişkin kategorileri şifre ile korunuyor'
                                      : 'Devre dışı • Yetişkin kategoriler şifresiz açılıyor',
                                ),
                                trailing: Icon(
                                  _parental.isProtectionEnabled
                                      ? Icons.lock_outline
                                      : Icons.lock_open_outlined,
                                  color: AppColors.neonPurple,
                                ),
                              ),
                            ),
                            _SettingsListCard(
                              glowColor: AppColors.neonPurple,
                              onActivate: _changePin,
                              child: const ListTile(
                                leading: Icon(
                                  Icons.password_outlined,
                                  color: AppColors.neonPurple,
                                  size: 32,
                                ),
                                title: Text(
                                  'Erişim Şifresini Değiştir',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  'Varsayılan şifre 0000 olarak tanımlanmıştır.',
                                ),
                              ),
                            ),
                            _SettingsListCard(
                              glowColor: AppColors.neonCyan,
                              onActivate: () {
                                AppUpdateFlow.check(
                                  context,
                                  context.read<AppUpdateService>(),
                                  force: true,
                                );
                              },
                              child: ListTile(
                                leading: const Icon(
                                  Icons.system_update_alt,
                                  color: AppColors.neonCyan,
                                  size: 32,
                                ),
                                title: const Text(
                                  'Güncellemeleri Denetle',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  'GitHub üzerinden yeni sürüm aranır. Yüklü sürüm ${AppVersionInfo.current.name}',
                                ),
                              ),
                            ),
                            _SettingsListCard(
                              glowColor: AppColors.neonPurple,
                              onActivate: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  PageRouteBuilder<void>(
                                    transitionDuration: const Duration(milliseconds: 300),
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const ProfileSelectionPage(),
                                    transitionsBuilder:
                                        (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                  (route) => false,
                                );
                              },
                              child: const ListTile(
                                leading: Icon(
                                  Icons.switch_account,
                                  color: AppColors.neonPurple,
                                  size: 32,
                                ),
                                title: Text(
                                  'Profil Yönetimi',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  'Aktif profili değiştirmek için profil seçim ekranına dönünüz.',
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Center(child: FalconLogo(height: 72)),
                  const SizedBox(height: 8),
                  Text(
                    'Sürüm ${AppVersionInfo.current.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _connectionSummary(ProfileModel? profile) {
    if (profile == null) {
      return 'Bağlantı bilgisi bulunmamaktadır.';
    }
    if (profile.type == ProfileType.xtream) {
      return 'Xtream Codes API • ${profile.serverUrl ?? '-'}';
    }
    return 'M3U Playlist • ${profile.m3uUrl ?? '-'}';
  }
}

class _SettingsListCard extends StatelessWidget {
  const _SettingsListCard({
    required this.child,
    required this.onActivate,
    required this.glowColor,
  });

  final Widget child;
  final VoidCallback onActivate;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeonFocusCard(
        glowColor: glowColor,
        focusedScale: 1.04,
        unfocusedOpacity: 0.85,
        onActivate: onActivate,
        child: child,
      ),
    );
  }
}
