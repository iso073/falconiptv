import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/update/app_update_flow.dart';
import '../../../../core/update/app_update_service.dart';
import '../../../../core/update/app_update_status_badge.dart';
import '../../../settings/presentation/widgets/sport_mode_status_badge.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/falcon_logo.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../iptv/data/models/playable_item.dart';
import '../../../library/data/watch_progress_repository.dart';
import '../../../library/presentation/playback_launcher.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../cubit/connection_cubit.dart';
import 'home_modules.dart';

class XCIPTVHomePage extends StatefulWidget {
  const XCIPTVHomePage({super.key});

  @override
  State<XCIPTVHomePage> createState() => _XCIPTVHomePageState();
}

class _XCIPTVHomePageState extends State<XCIPTVHomePage> {
  late DateTime _now;
  Timer? _clockTimer;

  static const List<_HomeModule> _modules = [
    _HomeModule(
      title: 'CANLI TV',
      icon: Icons.live_tv_rounded,
      glow: AppColors.neonCyan,
      onOpen: HomeModules.openLiveTv,
    ),
    _HomeModule(
      title: 'FİLMLER',
      icon: Icons.movie_outlined,
      glow: AppColors.neonPurple,
      onOpen: HomeModules.openMovies,
    ),
    _HomeModule(
      title: 'DİZİLER',
      icon: Icons.video_library_outlined,
      glow: AppColors.neonCyan,
      onOpen: HomeModules.openSeries,
    ),
    _HomeModule(
      title: 'ARAMA',
      icon: Icons.search_rounded,
      glow: AppColors.neonPurple,
      onOpen: HomeModules.openSearch,
    ),
    _HomeModule(
      title: 'FAVORİLER',
      icon: Icons.star_rounded,
      glow: AppColors.neonCyan,
      onOpen: HomeModules.openFavorites,
    ),
    _HomeModule(
      title: 'YAYIN AKIŞI',
      icon: Icons.calendar_month_outlined,
      glow: AppColors.neonPurple,
      onOpen: HomeModules.openEpg,
    ),
    _HomeModule(
      title: 'AYARLAR',
      icon: Icons.settings_outlined,
      glow: AppColors.neonCyan,
      onOpen: HomeModules.openSettings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final ProfileModel? profile = PlaybackLauncher.profileOf(context);
      context.read<ConnectionCubit>().refresh(profile);
      unawaited(AppUpdateFlow.check(context, context.read<AppUpdateService>()));
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year}  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final ProfileState profileState = context.watch<ProfileCubit>().state;
    final ProfileModel? profile =
        profileState is ProfileLoaded ? profileState.activeProfile : null;
    final String activeName = profile?.profileName ?? 'Profil atanmadı';
    final List<WatchProgress> resume = profile == null
        ? const <WatchProgress>[]
        : context.read<WatchProgressRepository>().continueWatching(profile.id);

    return TvBackScope(
      onBack: () => handleAppExit(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.ambientGlow),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
              child: Column(
                children: [
                  GlassmorphismBar(
                    child: Row(
                      children: [
                        const FalconLogo(height: 54, glow: true),
                        const SportModeStatusBadge(),
                        const Spacer(),
                        const AppUpdateStatusBadge(),
                        const SizedBox(width: 14),
                        const _ConnectionBadge(),
                        const SizedBox(width: 18),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              activeName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neonCyan,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateTime(_now),
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (resume.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kaldığınız yerden devam edin',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        clipBehavior: Clip.none,
                        scrollDirection: Axis.horizontal,
                        itemCount: resume.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final WatchProgress progress = resume[index];
                          return NeonFocusCard(
                            width: 280,
                            focusedScale: 1.04,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            onActivate: () => PlaybackLauncher.openPlaylist(
                              context,
                              <PlayableItem>[progress.item],
                              resumeFrom: progress.position,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  progress.item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress.fraction,
                                    minHeight: 6,
                                    color: AppColors.neonCyan,
                                    backgroundColor: Colors.white24,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Expanded(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: GridView.builder(
                        itemCount: _modules.length,
                        clipBehavior: Clip.none,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.35,
                        ),
                        itemBuilder: (context, index) {
                          final _HomeModule module = _modules[index];
                          return FocusTraversalOrder(
                            order: NumericFocusOrder(index.toDouble()),
                            child: NeonFocusCard(
                              autofocus: index == 0,
                              glowColor: module.glow,
                              onActivate: () => module.onOpen(context),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(module.icon, size: 48, color: module.glow),
                                  const SizedBox(height: 14),
                                  Text(
                                    module.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
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

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectionCubit, ConnectionSnapshot>(
      builder: (context, snapshot) {
        final Color color = switch (snapshot.phase) {
          ConnectionPhase.online => AppColors.success,
          ConnectionPhase.checking => AppColors.textSecondary,
          ConnectionPhase.offline => AppColors.danger,
          ConnectionPhase.serverIssue => const Color(0xFFFFC857),
        };
        return NeonFocusCard(
          focusedScale: 1.04,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          glowColor: color,
          onActivate: () {
            final ProfileModel? profile = PlaybackLauncher.profileOf(context);
            context.read<ConnectionCubit>().refresh(profile);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                snapshot.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeModule {
  const _HomeModule({
    required this.title,
    required this.icon,
    required this.glow,
    required this.onOpen,
  });

  final String title;
  final IconData icon;
  final Color glow;
  final void Function(BuildContext context) onOpen;
}
