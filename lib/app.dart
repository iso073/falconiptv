import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/hive_bootstrap.dart';
import 'core/constants/hive_boxes.dart';
import 'core/network/iptv_dio_client.dart';
import 'core/theme/app_theme.dart';
import 'core/update/app_update_service.dart';
import 'core/update/update_status_cubit.dart';
import 'features/home/presentation/cubit/connection_cubit.dart';
import 'features/iptv/data/repositories/iptv_catalog_repository.dart';
import 'features/iptv/data/repositories/m3u_repository.dart';
import 'features/iptv/data/repositories/xtream_repository.dart';
import 'features/library/data/favorites_repository.dart';
import 'features/library/data/watch_progress_repository.dart';
import 'features/profile/data/repositories/profile_repository.dart';
import 'features/profile/presentation/cubit/profile_cubit.dart';
import 'features/settings/data/parental_control_repository.dart';
import 'features/settings/data/sport_mode_repository.dart';
import 'features/settings/presentation/cubit/sport_mode_cubit.dart';
import 'features/splash/presentation/pages/splash_page.dart';

class FalconIptvApp extends StatefulWidget {
  const FalconIptvApp({super.key, required this.profileRepository});

  final ProfileRepository profileRepository;

  @override
  State<FalconIptvApp> createState() => _FalconIptvAppState();
}

class _FalconIptvAppState extends State<FalconIptvApp> {
  late final Dio _dio;
  late final XtreamRepository _xtreamRepository;
  late final M3uRepository _m3uRepository;
  late final IptvCatalogRepository _catalogRepository;
  bool _boxesReady = false;
  bool _openingBoxes = false;

  @override
  void initState() {
    super.initState();
    _dio = IptvDioClient.create();
    _xtreamRepository = XtreamRepository(_dio);
    _m3uRepository = M3uRepository(_dio);
    _catalogRepository = IptvCatalogRepository(
      m3uRepository: _m3uRepository,
      xtreamRepository: _xtreamRepository,
    );
    _ensureBoxes();
  }

  Future<void> _ensureBoxes() async {
    if (_boxesReady || _openingBoxes) {
      return;
    }
    _openingBoxes = true;
    await HiveBootstrap.openAll();
    if (mounted) {
      setState(() => _boxesReady = true);
    }
  }

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_boxesReady) {
      _ensureBoxes();
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      );
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProfileRepository>.value(value: widget.profileRepository),
        RepositoryProvider<XtreamRepository>.value(value: _xtreamRepository),
        RepositoryProvider<M3uRepository>.value(value: _m3uRepository),
        RepositoryProvider<IptvCatalogRepository>.value(value: _catalogRepository),
        RepositoryProvider<FavoritesRepository>(
          create: (_) => FavoritesRepository(Hive.box<dynamic>(HiveBoxes.favorites)),
        ),
        RepositoryProvider<WatchProgressRepository>(
          create: (_) => WatchProgressRepository(Hive.box<dynamic>(HiveBoxes.watchProgress)),
        ),
        RepositoryProvider<ParentalControlRepository>(
          create: (_) => ParentalControlRepository(
            Hive.box<dynamic>(HiveBoxes.settings),
          ),
        ),
        RepositoryProvider<AppUpdateService>(
          create: (_) => AppUpdateService(Hive.box<dynamic>(HiveBoxes.settings)),
        ),
        RepositoryProvider<SportModeRepository>(
          create: (_) => SportModeRepository(Hive.box<dynamic>(HiveBoxes.settings)),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ProfileCubit(widget.profileRepository)..loadProfiles()),
          BlocProvider(create: (_) => ConnectionCubit(_dio, _xtreamRepository)),
          BlocProvider(
            create: (context) => UpdateStatusCubit(context.read<AppUpdateService>())..refresh(),
          ),
          BlocProvider(
            create: (context) => SportModeCubit(context.read<SportModeRepository>()),
          ),
        ],
        child: MaterialApp(
          title: 'Falcon IPTV',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          // The TV layout is already sized for 10-foot viewing, so system font
          // scaling must not resize it.
          builder: (context, child) {
            return MediaQuery.withClampedTextScaling(
              minScaleFactor: 1,
              maxScaleFactor: 1,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashPage(),
        ),
      ),
    );
  }
}
