import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirm_dialog.dart';
import '../../../../core/widgets/glassmorphism_bar.dart';
import '../../../../core/widgets/neon_focus_card.dart';
import '../../../../core/widgets/tv_back_scope.dart';
import '../../../catalog/presentation/pages/catalog_browser_page.dart';
import '../../../iptv/data/models/playable_item.dart';
import '../../../iptv/data/models/series_details.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../iptv/data/repositories/m3u_repository.dart';
import '../playback_launcher.dart';

class SeriesDetailsPage extends StatefulWidget {
  const SeriesDetailsPage({super.key, required this.series});

  final PlayableItem series;

  @override
  State<SeriesDetailsPage> createState() => _SeriesDetailsPageState();
}

class _SeriesDetailsPageState extends State<SeriesDetailsPage> {
  SeriesDetails? _details;
  String? _error;
  bool _loading = true;
  int _seasonIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final SeriesDetails details = await context.read<IptvCatalogRepository>().loadSeriesDetails(
            PlaybackLauncher.profileOf(context),
            widget.series,
          );
      if (!mounted) {
        return;
      }
      if (details.seasons.isEmpty) {
        throw const IptvDataException('Bu dizi için bölüm listesi bulunamadı.');
      }
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SeriesDetails? details = _details;
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
                          autofocus: details == null,
                          width: 56,
                          height: 56,
                          padding: EdgeInsets.zero,
                          focusedScale: 1.08,
                          onActivate: () => Navigator.of(context).maybePop(),
                          child: const Center(child: Icon(Icons.arrow_back_rounded)),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.video_library_outlined, color: AppColors.neonCyan, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.series.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(child: _buildBody(details)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SeriesDetails? details) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.neonCyan));
    }
    if (_error != null || details == null) {
      return Center(
        child: Text(
          _error ?? 'Bölüm listesi alınamadı.',
          style: const TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      );
    }

    final SeriesSeason season = details.seasons[_seasonIndex.clamp(0, details.seasons.length - 1)];
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            itemCount: details.seasons.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bool selected = index == _seasonIndex;
              return NeonFocusCard(
                focusedScale: 1.04,
                unfocusedOpacity: selected ? 1 : 0.55,
                onActivate: () => setState(() => _seasonIndex = index),
                child: Text(
                  details.seasons[index].title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: selected ? AppColors.neonCyan : AppColors.textPrimary,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: GridView.builder(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            itemCount: season.episodes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              return CatalogTile(
                item: season.episodes[index],
                accent: AppColors.neonCyan,
                icon: Icons.play_circle_outline,
                autofocus: index == 0,
                onActivate: () => PlaybackLauncher.openPlaylist(
                  context,
                  season.episodes,
                  index: index,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
