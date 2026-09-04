import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/device/app_layout.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../iptv/data/models/playable_item.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../cubit/epg_cubit.dart';

class EpgPage extends StatelessWidget {
  const EpgPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileState profileState = context.read<ProfileCubit>().state;
    final ProfileModel? profile =
        profileState is ProfileLoaded ? profileState.activeProfile : null;

    return BlocProvider<EpgCubit>(
      create: (_) => EpgCubit(context.read<IptvCatalogRepository>(), profile)..load(),
      child: const _EpgView(),
    );
  }
}

class _EpgView extends StatelessWidget {
  const _EpgView();

  @override
  Widget build(BuildContext context) {
    return TvBackScope(
      onBack: () => popToPreviousPage(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.ambientGlow),
          child: SafeArea(
            child: Padding(
              padding: AppLayout.pagePadding(context),
              child: BlocBuilder<EpgCubit, EpgState>(
                builder: (context, state) {
                  return Column(
                    children: [
                      GlassmorphismBar(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            NeonFocusCard(
                              autofocus: state is! EpgLoaded,
                              width: AppLayout.backButton(context),
                              height: AppLayout.backButton(context),
                              padding: EdgeInsets.zero,
                              focusedScale: 1.08,
                              onActivate: () => Navigator.of(context).maybePop(),
                              child: const Center(child: Icon(Icons.arrow_back_rounded)),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: AppColors.neonPurple,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Yayın Akışı (EPG)',
                                style: TextStyle(
                                  fontSize: AppLayout.titleSize(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(child: ClipRect(child: _buildBody(context, state))),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, EpgState state) {
    if (state is EpgLoading || state is EpgInitial) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.neonPurple),
      );
    }

    if (state is EpgError) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy_rounded, size: 64, color: AppColors.danger),
              const SizedBox(height: 20),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 280,
                child: NeonFocusCard(
                  autofocus: true,
                  focusedScale: 1.06,
                  glowColor: AppColors.neonPurple,
                  onActivate: () => context.read<EpgCubit>().load(),
                  child: const Center(
                    child: Text(
                      'Yeniden Dene',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final EpgLoaded loaded = state as EpgLoaded;
    final List<EpgListing> listings = loaded.visibleListings;

    return Column(
      children: [
        SizedBox(
          height: 76,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            itemCount: loaded.channels.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final String channel = loaded.channels[index];
              final bool selected = channel == loaded.selectedChannel;
              return NeonFocusCard(
                glowColor: AppColors.neonPurple,
                focusedScale: 1.06,
                unfocusedOpacity: selected ? 1 : 0.55,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                onActivate: () => context.read<EpgCubit>().selectChannel(channel),
                child: Center(
                  child: Text(
                    channel,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            itemCount: listings.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final EpgListing listing = listings[index];
              return NeonFocusCard(
                glowColor: AppColors.neonPurple,
                focusedScale: 1.03,
                onActivate: () {},
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(
                        listing.timeRange,
                        style: const TextStyle(
                          color: AppColors.neonPurple,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            listing.channelName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
