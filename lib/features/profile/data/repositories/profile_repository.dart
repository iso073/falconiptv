import 'package:hive/hive.dart';

import '../../../../core/constants/hive_boxes.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  ProfileRepository({
    required this._profilesBox,
    required this._settingsBox,
  });

  final Box<ProfileModel> _profilesBox;
  final Box<dynamic> _settingsBox;

  Future<List<ProfileModel>> getAll() async {
    final List<ProfileModel> profiles = _profilesBox.values.toList();
    profiles.sort((a, b) => a.createdDate.compareTo(b.createdDate));
    return profiles;
  }

  Future<ProfileModel?> getById(String id) async {
    return _profilesBox.get(id);
  }

  Future<void> add(ProfileModel profile) async {
    await _profilesBox.put(profile.id, profile);
  }

  Future<void> update(ProfileModel profile) async {
    await _profilesBox.put(profile.id, profile);
  }

  Future<void> delete(String id) async {
    await _profilesBox.delete(id);
    if (getActiveId() == id) {
      await _settingsBox.delete(HiveBoxes.activeProfileIdKey);
    }
  }

  Future<void> setActive(String id) async {
    if (!_profilesBox.containsKey(id)) {
      throw StateError('Seçilen profil sistemde bulunamadı.');
    }
    await _settingsBox.put(HiveBoxes.activeProfileIdKey, id);
  }

  String? getActiveId() {
    final Object? value = _settingsBox.get(HiveBoxes.activeProfileIdKey);
    return value is String ? value : null;
  }

  Future<ProfileModel?> getActive() async {
    final String? id = getActiveId();
    if (id == null) {
      return null;
    }
    return _profilesBox.get(id);
  }

  Future<void> clearActive() async {
    await _settingsBox.delete(HiveBoxes.activeProfileIdKey);
  }
}
