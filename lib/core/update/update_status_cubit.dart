import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_update_config.dart';
import 'app_update_service.dart';

enum UpdateStatusPhase { checking, current, available, failed }

class UpdateStatusState {
  const UpdateStatusState({
    this.phase = UpdateStatusPhase.checking,
    this.release,
  });

  final UpdateStatusPhase phase;
  final GithubReleaseInfo? release;

  String get title => switch (phase) {
        UpdateStatusPhase.checking => 'Denetleniyor',
        UpdateStatusPhase.current => 'Güncel ${AppVersionInfo.current.name}',
        UpdateStatusPhase.available =>
          release == null ? 'Güncelleme var' : '${release!.version.name} var',
        UpdateStatusPhase.failed => 'Denetlenemedi',
      };
}

class UpdateStatusCubit extends Cubit<UpdateStatusState> {
  UpdateStatusCubit(this._service) : super(const UpdateStatusState());

  final AppUpdateService _service;

  Future<void> refresh() async {
    emit(const UpdateStatusState());
    try {
      final GithubReleaseInfo? latest = await _service.fetchLatest();
      if (latest == null) {
        emit(const UpdateStatusState(phase: UpdateStatusPhase.failed));
        return;
      }
      final bool newer = latest.version.isNewerThan(AppVersionInfo.current);
      emit(
        UpdateStatusState(
          phase: newer ? UpdateStatusPhase.available : UpdateStatusPhase.current,
          release: latest,
        ),
      );
    } catch (_) {
      emit(const UpdateStatusState(phase: UpdateStatusPhase.failed));
    }
  }
}
