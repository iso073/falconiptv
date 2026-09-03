import 'package:flutter/material.dart';

import '../../../catalog/presentation/pages/epg_page.dart';
import '../../../catalog/presentation/pages/live_tv_page.dart';
import '../../../library/presentation/pages/favorites_page.dart';
import '../../../library/presentation/pages/search_page.dart';
import 'settings_page.dart';

abstract final class HomeModules {
  static void openLiveTv(BuildContext context) => _push(context, const LiveTvPage());

  static void openMovies(BuildContext context) => _push(context, const MoviesPage());

  static void openSeries(BuildContext context) => _push(context, const SeriesPage());

  static void openEpg(BuildContext context) => _push(context, const EpgPage());

  static void openSettings(BuildContext context) => _push(context, const SettingsPage());

  static void openSearch(BuildContext context) => _push(context, const SearchPage());

  static void openFavorites(BuildContext context) => _push(context, const FavoritesPage());

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}
