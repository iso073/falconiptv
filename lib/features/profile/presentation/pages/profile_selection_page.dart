import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/tv_toast_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/device/app_layout.dart';
import '../../../../core/device/form_factor.dart';
import '../../../../core/update/app_update_status_badge.dart';
import '../../../settings/presentation/widgets/sport_mode_status_badge.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/falcon_logo.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../home/presentation/pages/xciptv_home_page.dart';
import '../../data/models/profile_model.dart';
import '../cubit/profile_cubit.dart';
import 'add_profile_page.dart';
import 'qr_add_profile_page.dart';

class ProfileSelectionPage extends StatelessWidget {
  const ProfileSelectionPage({super.key});

  Future<void> navigateToHome(BuildContext context, ProfileModel profile) async {
    final ProfileCubit cubit = context.read<ProfileCubit>();
    await cubit.selectProfile(profile.id);
    if (!context.mounted || cubit.state is ProfileError) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => const XCIPTVHomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _openQrProfile(BuildContext context) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => const QrAddProfilePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _openAddProfile(BuildContext context, {ProfileModel? existing}) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddProfilePage(existing: existing),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TvBackScope(
      onBack: () => handleAppExit(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.ambientGlow),
          child: SafeArea(
            child: Padding(
              padding: AppLayout.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassmorphismBar(
                    child: Row(
                      children: [
                        FalconLogo(height: AppLayout.headerLogo(context), glow: true),
                        const SportModeStatusBadge(),
                        const SizedBox(width: 16),
                        Text(
                          'Profil Seçimi',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: FormFactor.isPhoneOf(context) ? 18 : null,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                        ),
                        const Spacer(),
                        const AppUpdateStatusBadge(),
                      ],
                    ),
                  ),
                  SizedBox(height: FormFactor.isPhoneOf(context) ? 8 : 24),
                  Expanded(
                    child: BlocConsumer<ProfileCubit, ProfileState>(
                      listener: (context, state) {
                        if (state is ProfileError) {
                          TvToastService.show(context, state.message);
                        }
                      },
                      builder: (context, state) {
                        if (state is ProfileLoading || state is ProfileInitial) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.neonCyan),
                          );
                        }
                        if (state is ProfileError) {
                          return Center(
                            child: NeonFocusCard(
                              autofocus: true,
                              onActivate: () => context.read<ProfileCubit>().loadProfiles(),
                              child: const Text(
                                'Yeniden Dene',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                            ),
                          );
                        }
                        final ProfileLoaded loaded = state as ProfileLoaded;
                        final bool phone = FormFactor.isPhoneOf(context);
                        final int itemCount = loaded.profiles.length + (phone ? 1 : 2);
                        final double cardWidth = AppLayout.profileCardWidth(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loaded.profiles.isEmpty
                                  ? (phone
                                      ? 'Kayıtlı profil bulunmamaktadır. Yeni profil ekleyiniz.'
                                      : 'Kayıtlı profil bulunmamaktadır. Kumanda ile veya telefondaki karekod ile yeni profil ekleyiniz.')
                                  : 'Kullanmak istediğiniz yayın profilini seçiniz.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: phone ? 14 : 19,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: phone ? 8 : 18),
                            Expanded(
                              child: ListView.separated(
                                clipBehavior: Clip.none,
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(
                                  vertical: phone ? 4 : 12,
                                  horizontal: phone ? 4 : 8,
                                ),
                                itemCount: itemCount,
                                separatorBuilder: (context, index) => const SizedBox(width: 22),
                                itemBuilder: (context, index) {
                                  final bool isAddCard = index == loaded.profiles.length;
                                  final bool isQrCard = index == loaded.profiles.length + 1;
                                  if (isAddCard) {
                                    return SizedBox(
                                      width: cardWidth,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: NeonFocusCard(
                                              autofocus: loaded.profiles.isEmpty,
                                              glowColor: AppColors.neonPurple,
                                              padding: phone
                                                  ? const EdgeInsets.all(10)
                                                  : const EdgeInsets.all(18),
                                              onActivate: () => _openAddProfile(context),
                                              child: phone
                                                  ? FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: _AddProfileCardBody(compact: true),
                                                    )
                                                  : const _AddProfileCardBody(compact: false),
                                            ),
                                          ),
                                          SizedBox(height: phone ? 6 : 10),
                                          SizedBox(height: phone ? 36 : 46),
                                        ],
                                      ),
                                    );
                                  }
                                  if (isQrCard) {
                                    if (phone) {
                                      return const SizedBox.shrink();
                                    }
                                    return SizedBox(
                                      width: cardWidth,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: NeonFocusCard(
                                              glowColor: AppColors.neonCyan,
                                              padding: phone
                                                  ? const EdgeInsets.all(10)
                                                  : const EdgeInsets.all(18),
                                              onActivate: () => _openQrProfile(context),
                                              child: const _QrProfileCardBody(),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const SizedBox(height: 46),
                                        ],
                                      ),
                                    );
                                  }

                                  final ProfileModel profile = loaded.profiles[index];
                                  final bool isXtream = profile.type == ProfileType.xtream;
                                  return SizedBox(
                                    width: cardWidth,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: NeonFocusCard(
                                            autofocus: index == 0,
                                            glowColor: isXtream
                                                ? AppColors.neonCyan
                                                : AppColors.neonPurple,
                                            padding: phone
                                                ? const EdgeInsets.all(10)
                                                : const EdgeInsets.all(18),
                                            onActivate: () => navigateToHome(context, profile),
                                            onLongPress: () =>
                                                _openAddProfile(context, existing: profile),
                                            child: phone
                                                ? FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment: Alignment.centerLeft,
                                                    child: SizedBox(
                                                      width: cardWidth - 28,
                                                      child: _ProfileCardBody(
                                                        profile: profile,
                                                        compact: true,
                                                      ),
                                                    ),
                                                  )
                                                : _ProfileCardBody(
                                                    profile: profile,
                                                    compact: false,
                                                  ),
                                          ),
                                        ),
                                        SizedBox(height: phone ? 8 : 20),
                                        SizedBox(
                                          height: phone ? 36 : 46,
                                          child: NeonFocusCard(
                                            padding: EdgeInsets.zero,
                                            borderRadius: 14,
                                            focusedScale: 1.06,
                                            unfocusedOpacity: 0.85,
                                            glowColor: AppColors.neonCyan,
                                            onActivate: () =>
                                                _openAddProfile(context, existing: profile),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  color: AppColors.neonCyan,
                                                  size: 22,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Düzenle',
                                                  style: TextStyle(
                                                    color: AppColors.neonCyan,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              phone
                                  ? 'Düzenlemek için kartın altındaki Düzenle düğmesine basınız.'
                                  : 'Düzenlemek veya silmek için kartın altındaki "Düzenle" düğmesine '
                                      'ilerleyiniz. Kart üzerinde OK tuşunu basılı tutmak da düzenlemeyi açar.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: phone ? 12 : 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        );
                      },
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

class _AddProfileCardBody extends StatelessWidget {
  const _AddProfileCardBody({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Icon(
          Icons.add_circle_outline,
          size: compact ? 36 : 52,
          color: AppColors.neonPurple,
        ),
        SizedBox(height: compact ? 8 : 14),
        Text(
          '+ Yeni Profil Ekle',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _QrProfileCardBody extends StatelessWidget {
  const _QrProfileCardBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_2_rounded,
          size: 52,
          color: AppColors.neonCyan,
        ),
        SizedBox(height: 14),
        Text(
          'Telefondan Ekle',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ProfileCardBody extends StatelessWidget {
  const _ProfileCardBody({required this.profile, required this.compact});

  final ProfileModel profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool isXtream = profile.type == ProfileType.xtream;
    final Color color = isXtream ? AppColors.neonCyan : AppColors.neonPurple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: _TypeBadge(type: profile.type),
        ),
        if (compact) const SizedBox(height: 8) else const Spacer(),
        CircleAvatar(
          radius: compact ? 18 : 24,
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(
            isXtream ? Icons.cloud_outlined : Icons.playlist_play,
            color: color,
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          profile.profileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 16 : 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Text(
          isXtream ? (profile.serverUrl ?? 'Xtream Codes bağlantısı') : 'M3U oynatma listesi',
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final ProfileType type;

  @override
  Widget build(BuildContext context) {
    final bool isXtream = type == ProfileType.xtream;
    final Color color = isXtream ? AppColors.neonCyan : AppColors.neonPurple;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          isXtream ? 'Xtream' : 'M3U',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
