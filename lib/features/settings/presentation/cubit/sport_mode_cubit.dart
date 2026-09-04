import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sport_mode_repository.dart';

class SportModeCubit extends Cubit<bool> {
  SportModeCubit(this._repository) : super(_repository.enabled);

  final SportModeRepository _repository;

  Future<void> setEnabled(bool value) async {
    await _repository.setEnabled(value);
    emit(value);
  }
}
