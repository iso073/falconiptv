import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/tv_toast_service.dart';
import '../../iptv/data/models/playable_item.dart';
import '../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../player/presentation/pages/video_player_page.dart';
import '../../profile/data/models/profile_model.dart';
import '../../profile/presentation/cubit/profile_cubit.dart';
import '../presentation/pages/series_details_page.dart';

abstract final class PlaybackLauncher {
  static ProfileModel? profileOf(BuildContext context) {
    final ProfileState state = context.read<ProfileCubit>().state;
    return state is ProfileLoaded ? state.activeProfile : null;
  }

  static Future<void> openItem(BuildContext context, PlayableItem item) {
    if (item.isSeriesShell) {
      return Navigator.of(context).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              SeriesDetailsPage(series: item),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
    return openPlaylist(context, <PlayableItem>[item]);
  }

  static Future<void> openPlaylist(
    BuildContext context,
    List<PlayableItem> playlist, {
    int index = 0,
    Duration? resumeFrom,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => VideoPlayerPage(
          playlist: playlist,
          initialIndex: index,
          resumeFrom: resumeFrom,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static Future<void> openResolved(
    BuildContext context,
    List<PlayableItem> playlist,
    int index,
  ) async {
    final PlayableItem item = playlist[index];
    if (item.isSeriesShell) {
      await openItem(context, item);
      return;
    }
    try {
      playlist[index] = await context.read<IptvCatalogRepository>().resolvePlayable(
            profileOf(context),
            item,
          );
    } catch (error) {
      if (context.mounted) {
        TvToastService.show(context, '$error');
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    await openPlaylist(context, playlist, index: index);
  }
}
