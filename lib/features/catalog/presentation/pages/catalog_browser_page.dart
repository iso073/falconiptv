import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/tv_toast_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../iptv/data/models/playable_item.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../library/data/favorites_repository.dart';
import '../../../library/presentation/playback_launcher.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../settings/data/parental_control_repository.dart';
import '../../../settings/presentation/widgets/pin_entry_dialog.dart';
import '../cubit/catalog_cubit.dart';

class CatalogBrowserPage extends StatelessWidget {
  const CatalogBrowserPage({
    super.key,
    required this.title,
    required this.icon,
    required this.section,
    this.accent = AppColors.neonCyan,
  });

  final String title;
  final IconData icon;
  final CatalogSection section;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ProfileState profileState = context.read<ProfileCubit>().state;
    final ProfileModel? profile =
        profileState is ProfileLoaded ? profileState.activeProfile : null;

    return BlocProvider<CatalogCubit>(
      create: (_) => CatalogCubit(
        context.read<IptvCatalogRepository>(),
        context.read<ParentalControlRepository>(),
        section,
        profile,
      )..load(),
      child: _CatalogBrowserView(title: title, icon: icon, accent: accent),
    );
  }
}

class _CatalogBrowserView extends StatelessWidget {
  const _CatalogBrowserView({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;

  Future<void> _selectCategory(BuildContext context, String category) async {
    final CatalogCubit cubit = context.read<CatalogCubit>();
    if (cubit.selectCategory(category)) {
      return;
    }

    final String? entered = await showPinEntryDialog(
      context: context,
      title: 'Yetişkin İçerik Koruması',
      message: 'Bu kategoriyi görüntülemek için erişim şifresini giriniz.',
    );
    if (entered == null || !context.mounted) {
      return;
    }
    if (!context.read<ParentalControlRepository>().verifyPin(entered)) {
      TvToastService.show(context, 'Girilen şifre hatalıdır.');
      return;
    }
    cubit.unlockAdultContent();
    cubit.selectCategory(category);
    if (context.mounted) {
      TvToastService.show(
        context,
        'Yetişkin içerik erişimi bu oturum için açıldı.',
        type: TvToastType.success,
      );
    }
  }

  Future<void> _play(BuildContext context, List<PlayableItem> playlist, int index) {
    return PlaybackLauncher.openResolved(context, List<PlayableItem>.from(playlist), index);
  }

  Future<void> _toggleFavorite(BuildContext context, PlayableItem item) async {
    final ProfileModel? profile = PlaybackLauncher.profileOf(context);
    if (profile == null) {
      return;
    }
    await context.read<FavoritesRepository>().toggle(profile.id, item);
    if (!context.mounted) {
      return;
    }
    final bool added = context.read<FavoritesRepository>().isFavorite(profile.id, item);
    TvToastService.show(
      context,
      added ? '"${item.title}" favorilere eklendi.' : '"${item.title}" favorilerden çıkarıldı.',
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
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              child: BlocBuilder<CatalogCubit, CatalogState>(
                builder: (context, state) {
                  return Column(
                    children: [
                      GlassmorphismBar(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            NeonFocusCard(
                              autofocus: state is! CatalogLoaded,
                              width: 56,
                              height: 56,
                              padding: EdgeInsets.zero,
                              focusedScale: 1.08,
                              onActivate: () => Navigator.of(context).maybePop(),
                              child: const Center(child: Icon(Icons.arrow_back_rounded)),
                            ),
                            const SizedBox(width: 16),
                            Icon(icon, color: accent, size: 32),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                              ),
                            ),
                            if (state is CatalogLoaded)
                              Text(
                                '${state.visibleItems.length} kayıt',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Expanded(child: _buildBody(context, state)),
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

  Widget _buildBody(BuildContext context, CatalogState state) {
    if (state is CatalogLoading || state is CatalogInitial) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accent),
            const SizedBox(height: 20),
            const Text(
              'İçerik listesi sunucudan alınıyor...',
              style: TextStyle(fontSize: 20, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state is CatalogError) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.danger),
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
                  onActivate: () => context.read<CatalogCubit>().load(forceRefresh: true),
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

    final CatalogLoaded loaded = state as CatalogLoaded;
    final List<PlayableItem> items = loaded.visibleItems;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 280,
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            itemCount: loaded.categories.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final String category = loaded.categories[index];
              final bool selected = category == loaded.selectedCategory;
              final bool locked = context.read<CatalogCubit>().isCategoryLocked(category);
              return NeonFocusCard(
                glowColor: locked ? AppColors.neonPurple : accent,
                focusedScale: 1.05,
                unfocusedOpacity: selected ? 1 : 0.55,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                onActivate: () => _selectCategory(context, category),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: selected ? accent : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (locked)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: AppColors.neonPurple,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'Bu kategoride yayın bulunmamaktadır.',
                    style: TextStyle(fontSize: 20, color: AppColors.textSecondary),
                  ),
                )
              : GridView.builder(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    return CatalogTile(
                      item: items[index],
                      accent: accent,
                      icon: icon,
                      autofocus: index == 0,
                      onActivate: () => _play(context, items, index),
                      onLongPress: () => _toggleFavorite(context, items[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class CatalogTile extends StatelessWidget {
  const CatalogTile({
    super.key,
    required this.item,
    required this.accent,
    required this.icon,
    required this.onActivate,
    this.onLongPress,
    this.autofocus = false,
  });

  // Reserved so long channel names can wrap to two lines without pushing the
  // thumbnail out of the card.
  static const double _labelHeight = 62;

  final PlayableItem item;
  final Color accent;
  final IconData icon;
  final VoidCallback onActivate;
  final VoidCallback? onLongPress;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return NeonFocusCard(
      autofocus: autofocus,
      glowColor: accent,
      focusedScale: 1.07,
      padding: const EdgeInsets.all(12),
      onActivate: onActivate,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _Thumbnail(item: item, accent: accent, icon: icon)),
          const SizedBox(height: 8),
          SizedBox(
            height: _labelHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.accent, required this.icon});

  final PlayableItem item;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final String? logo = item.logoUrl;
    if (logo == null || logo.isEmpty) {
      return Center(child: Icon(icon, color: accent, size: 40));
    }
    return Center(
      child: Image.network(
        logo,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Icon(icon, color: accent, size: 40),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return Icon(icon, color: accent.withValues(alpha: 0.4), size: 40);
        },
      ),
    );
  }
}
