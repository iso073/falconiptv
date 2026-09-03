import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../iptv/data/models/playable_item.dart';
import '../../../iptv/data/repositories/iptv_catalog_repository.dart';
import '../../../iptv/data/repositories/m3u_repository.dart';
import '../../../profile/data/models/profile_model.dart';

part 'epg_state.dart';

class EpgCubit extends Cubit<EpgState> {
  EpgCubit(this._repository, this._profile) : super(const EpgInitial());

  final IptvCatalogRepository _repository;
  final ProfileModel? _profile;

  Future<void> load() async {
    emit(const EpgLoading());
    try {
      final List<EpgListing> listings = await _repository.loadEpg(_profile);
      final List<String> channels = <String>[];
      for (final EpgListing listing in listings) {
        if (!channels.contains(listing.channelName)) {
          channels.add(listing.channelName);
        }
      }
      emit(
        EpgLoaded(
          listings: listings,
          channels: <String>['Tümü', ...channels],
          selectedChannel: 'Tümü',
        ),
      );
    } on IptvDataException catch (error) {
      emit(EpgError(error.message));
    } catch (_) {
      emit(
        const EpgError(
          'Yayın akışı alınamadı. Lütfen bağlantınızı kontrol ediniz.',
        ),
      );
    }
  }

  void selectChannel(String channel) {
    final EpgState current = state;
    if (current is EpgLoaded) {
      emit(current.copyWith(selectedChannel: channel));
    }
  }
}
