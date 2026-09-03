import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../iptv/data/models/playable_item.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../iptv/data/repositories/m3u_repository.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../settings/data/parental_control_repository.dart';
import '../../../settings/domain/adult_content_policy.dart';

part 'catalog_state.dart';

class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository, this._parental, this._section, this._profile)
      : super(const CatalogInitial());

  final IptvCatalogRepository _repository;
  final ParentalControlRepository _parental;
  final CatalogSection _section;
  final ProfileModel? _profile;

  bool get isAdultUnlocked => _parental.isUnlocked;

  Future<void> load({bool forceRefresh = false}) async {
    emit(const CatalogLoading());
    try {
      final CatalogSnapshot snapshot = await _repository.loadSection(
        _profile,
        _section,
        forceRefresh: forceRefresh,
      );
      emit(
        CatalogLoaded(
          categories: snapshot.categories,
          items: snapshot.items,
          selectedCategory: snapshot.categories.first,
          adultUnlocked: _parental.isUnlocked,
        ),
      );
    } on IptvDataException catch (error) {
      emit(CatalogError(error.message));
    } catch (_) {
      emit(
        const CatalogError(
          'İçerik listesi alınamadı. Lütfen sunucu bilgilerinizi ve internet bağlantınızı kontrol ediniz.',
        ),
      );
    }
  }

  /// Returns false when the category is locked, so the page can ask for the PIN.
  bool selectCategory(String category) {
    final CatalogState current = state;
    if (current is! CatalogLoaded) {
      return true;
    }
    if (AdultContentPolicy.isAdult(category) && !_parental.isUnlocked) {
      return false;
    }
    emit(current.copyWith(selectedCategory: category));
    return true;
  }

  void unlockAdultContent() {
    _parental.unlockSession();
    final CatalogState current = state;
    if (current is CatalogLoaded) {
      emit(current.copyWith(adultUnlocked: true));
    }
  }

  bool isCategoryLocked(String category) =>
      AdultContentPolicy.isAdult(category) && !_parental.isUnlocked;

  Future<PlayableItem> resolvePlayable(PlayableItem item) {
    return _repository.resolvePlayable(_profile, item);
  }
}
