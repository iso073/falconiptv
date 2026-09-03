import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository) : super(const ProfileInitial());

  final ProfileRepository _repository;

  Future<void> loadProfiles() async {
    emit(const ProfileLoading());
    try {
      final List<ProfileModel> profiles = await _repository.getAll();
      final ProfileModel? active = await _repository.getActive();
      emit(ProfileLoaded(profiles: profiles, activeProfile: active));
    } catch (_) {
      emit(
        const ProfileError(
          'Profiller yüklenirken bir sorun oluştu. Lütfen yeniden deneyiniz.',
        ),
      );
    }
  }

  Future<void> addProfile(ProfileModel profile) async {
    try {
      await _repository.add(profile);
      await loadProfiles();
    } catch (_) {
      emit(
        const ProfileError(
          'Profil kaydı oluşturulamadı. Lütfen bilgilerinizi kontrol ediniz.',
        ),
      );
    }
  }

  Future<void> deleteProfile(String id) async {
    try {
      await _repository.delete(id);
      await loadProfiles();
    } catch (_) {
      emit(
        const ProfileError(
          'Profil silinemedi. İşlem daha sonra tekrar denenebilir.',
        ),
      );
    }
  }

  Future<void> selectProfile(String id) async {
    try {
      await _repository.setActive(id);
      await loadProfiles();
    } catch (_) {
      emit(
        const ProfileError(
          'Aktif profil seçilemedi. Lütfen geçerli bir profil belirleyiniz.',
        ),
      );
    }
  }
}
