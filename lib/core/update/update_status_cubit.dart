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
        UpdateStatusPhase.current => 'Güncelsiniz',
        UpdateStatusPhase.available => 'Güncelleme var',
        UpdateStatusPhase.failed => 'Denetlenemedi',
      };
}

class UpdateStatusCubit extends Cubit<UpdateStatusState> {
  UpdateStatusCubit(this._service) : super(const UpdateStatusState());

  final AppUpdateService _service;

  Future<void> refresh() async {
    emit(const UpdateStatusState());
    try {
      final GithubReleaseInfo? update = await _service.availableUpdate();
      emit(
        UpdateStatusState(
          phase: update == null ? UpdateStatusPhase.current : UpdateStatusPhase.available,
          release: update,
        ),
      );
    } catch (_) {
      emit(const UpdateStatusState(phase: UpdateStatusPhase.failed));
    }
  }
}
