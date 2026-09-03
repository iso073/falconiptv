import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../catalog/presentation/pages/catalog_browser_page.dart';
import '../../../iptv/data/models/playable_item.dart';
import '../../../library/data/favorites_repository.dart';
import '../../../profile/data/models/profile_model.dart';
import '../playback_launcher.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  Widget build(BuildContext context) {
    final ProfileModel? profile = PlaybackLauncher.profileOf(context);
    final List<PlayableItem> items = profile == null
        ? const <PlayableItem>[]
        : context.read<FavoritesRepository>().list(profile.id);

    return TvBackScope(
      onBack: () => popToPreviousPage(context),
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.ambientGlow),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              child: Column(
                children: [
                  GlassmorphismBar(
                    child: Row(
                      children: [
                        NeonFocusCard(
                          autofocus: items.isEmpty,
                          width: 56,
                          height: 56,
                          padding: EdgeInsets.zero,
                          focusedScale: 1.08,
                          onActivate: () => Navigator.of(context).maybePop(),
                          child: const Center(child: Icon(Icons.arrow_back_rounded)),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.star_rounded, color: AppColors.neonPurple, size: 32),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Favoriler',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${items.length} kayıt',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text(
                              'Henüz favori eklenmedi. Bir karta uzun basarak ekleyebilirsiniz.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, color: AppColors.textSecondary),
                            ),
                          )
                        : GridView.builder(
                            clipBehavior: Clip.none,
                            itemCount: items.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1,
                            ),
                            itemBuilder: (context, index) {
                              final PlayableItem item = items[index];
                              return CatalogTile(
                                item: item,
                                accent: AppColors.neonPurple,
                                icon: Icons.star_rounded,
                                autofocus: index == 0,
                                onActivate: () => PlaybackLauncher.openItem(context, item),
                                onLongPress: () async {
                                  if (profile == null) {
                                    return;
                                  }
                                  await context.read<FavoritesRepository>().toggle(profile.id, item);
                                  if (mounted) {
                                    setState(() {});
                                  }
                                },
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
