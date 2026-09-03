import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/constants/hive_bootstrap.dart';
import 'core/constants/hive_boxes.dart';
import 'features/profile/data/models/profile_model.dart';
import 'features/profile/data/repositories/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ProfileModelAdapter());
  }

  final Box<ProfileModel> profilesBox = await Hive.openBox<ProfileModel>(HiveBoxes.profiles);
  await HiveBootstrap.openAll();

  final ProfileRepository profileRepository = ProfileRepository(
    profilesBox: profilesBox,
    settingsBox: Hive.box<dynamic>(HiveBoxes.settings),
  );

  runApp(FalconIptvApp(profileRepository: profileRepository));
}
