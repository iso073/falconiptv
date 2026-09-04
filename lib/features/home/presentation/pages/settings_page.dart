import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../../../settings/presentation/cubit/sport_mode_cubit.dart';
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

  Future<void> _toggleSportMode() async {
    final SportModeCubit cubit = context.read<SportModeCubit>();
    if (cubit.state) {
      await cubit.setEnabled(false);
      if (!mounted) {
        return;
      }
      TvToastService.show(context, 'Spor modu kapatıldı.');
      return;
    }

    final bool confirmed = await showNeonConfirmDialog(
      context: context,
      title: 'Spor Modu',
      message:
          'Maç günlerinde takılmayı azaltmak için yayın daha uzun tamponlanır. Kanal bir süre geç açılabilir. Açmak istiyor musunuz?',
      cancelLabel: 'Vazgeç',
      confirmLabel: 'Aç',
      confirmColor: AppColors.neonCyan,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await cubit.setEnabled(true);
    if (!mounted) {
      return;
    }
    TvToastService.show(
      context,
      'Spor modu açıldı. Yeni yayında uzun tampon kullanılır.',
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
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: GlassmorphismBar(
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
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: BlocBuilder<ProfileCubit, ProfileState>(
                      builder: (context, state) {
                        final ProfileModel? profile =
                            state is ProfileLoaded ? state.activeProfile : null;
                        return ClipRect(
                          child: ListView(
                            clipBehavior: Clip.hardEdge,
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
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
                                    subtitle: Text(
                                      '${snapshot.title} • ${snapshot.detail}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                subtitle: Text(
                                  _connectionSummary(profile),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            BlocBuilder<SportModeCubit, bool>(
                              builder: (context, sportOn) {
                                return _SettingsListCard(
                                  glowColor: AppColors.neonCyan,
                                  onActivate: _toggleSportMode,
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.sports_soccer_rounded,
                                      color: AppColors.neonCyan,
                                      size: 32,
                                    ),
                                    title: const Text(
                                      'Spor Modu',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(
                                      sportOn
                                          ? 'Açık • Maç yayını için uzun tampon'
                                          : 'Kapalı • Normal tampon kullanılır',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Icon(
                                      sportOn ? Icons.toggle_on_rounded : Icons.toggle_off_outlined,
                                      color: sportOn ? AppColors.neonCyan : AppColors.textSecondary,
                                      size: 36,
                                    ),
                                  ),
                                );
                              },
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          ),
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
    final String raw = profile.type == ProfileType.xtream
        ? (profile.serverUrl ?? '-')
        : (profile.m3uUrl ?? '-');
    final String compact = _compactUrl(raw);
    if (profile.type == ProfileType.xtream) {
      return 'Xtream Codes API • $compact';
    }
    return 'M3U Playlist • $compact';
  }

  String _compactUrl(String raw) {
    final Uri? uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.host.isEmpty) {
      return raw;
    }
    final String path = uri.path;
    if (path.isEmpty || path == '/') {
      return uri.host;
    }
    return '${uri.host}$path';
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _StableListFocus(
        child: NeonFocusCard(
          glowColor: glowColor,
          focusedScale: 1.0,
          unfocusedOpacity: 0.85,
          borderRadius: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          onActivate: onActivate,
          child: Theme(
            data: Theme.of(context).copyWith(
              listTileTheme: const ListTileThemeData(
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                minVerticalPadding: 12,
                minLeadingWidth: 40,
                visualDensity: VisualDensity.standard,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _StableListFocus extends SingleChildRenderObjectWidget {
  const _StableListFocus({required Widget child}) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStableListFocus();
}

class _RenderStableListFocus extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    final RenderObject? viewport = RenderAbstractViewport.maybeOf(this);
    final RenderObject? target = descendant ?? child;
    if (viewport is! RenderBox || target is! RenderBox || !viewport.hasSize || !target.hasSize) {
      super.showOnScreen(
        descendant: descendant,
        rect: rect,
        duration: duration,
        curve: curve,
      );
      return;
    }
    final RenderBox viewBox = viewport;
    final RenderBox itemBox = target;
    final Rect view = viewBox.localToGlobal(Offset.zero) & viewBox.size;
    final Rect item = itemBox.localToGlobal(Offset.zero) & itemBox.size;
    if (item.top >= view.top && item.bottom <= view.bottom) {
      return;
    }
    super.showOnScreen(
      descendant: descendant,
      rect: rect,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}
