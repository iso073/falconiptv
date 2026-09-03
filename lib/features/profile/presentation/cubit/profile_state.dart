part of 'profile_cubit.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileLoaded extends ProfileState {
  const ProfileLoaded({
    required this.profiles,
    this.activeProfile,
  });

  final List<ProfileModel> profiles;
  final ProfileModel? activeProfile;
}

class ProfileError extends ProfileState {
  const ProfileError(this.message);

  final String message;
}
