import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import 'catalog_browser_page.dart';

class LiveTvPage extends StatelessWidget {
  const LiveTvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CatalogBrowserPage(
      title: 'Canlı TV',
      icon: Icons.live_tv_rounded,
      section: CatalogSection.live,
    );
  }
}

class MoviesPage extends StatelessWidget {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CatalogBrowserPage(
      title: 'Filmler',
      icon: Icons.movie_outlined,
      section: CatalogSection.movies,
      accent: AppColors.neonPurple,
    );
  }
}

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CatalogBrowserPage(
      title: 'Diziler',
      icon: Icons.video_library_outlined,
      section: CatalogSection.series,
    );
  }
}
