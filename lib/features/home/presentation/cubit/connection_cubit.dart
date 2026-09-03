import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../iptv/data/models/series_details.dart';
import '../../../iptv/data/repositories/m3u_repository.dart';
import '../../../iptv/data/repositories/xtream_repository.dart';
import '../../../iptv/domain/xtream_link_parser.dart';
import '../../../profile/data/models/profile_model.dart';

part 'connection_state.dart';

class ConnectionCubit extends Cubit<ConnectionSnapshot> {
  ConnectionCubit(this._dio, this._xtream) : super(const ConnectionSnapshot.checking());

  final Dio _dio;
  final XtreamRepository _xtream;

  Future<void> refresh(ProfileModel? profile) async {
    emit(state.copyWith(phase: ConnectionPhase.checking));
    try {
      await _dio.get<void>(
        'https://clients3.google.com/generate_204',
        options: Options(
          followRedirects: false,
          validateStatus: (int? status) => status != null && status < 500,
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 6),
        ),
      );
    } catch (_) {
      emit(
        const ConnectionSnapshot(
          phase: ConnectionPhase.offline,
          title: 'Çevrimdışı',
          detail: 'İnternet bağlantısı algılanamadı.',
        ),
      );
      return;
    }

    if (profile == null) {
      emit(
        const ConnectionSnapshot(
          phase: ConnectionPhase.online,
          title: 'Çevrimiçi',
          detail: 'Aktif profil seçilmedi.',
        ),
      );
      return;
    }

    try {
      final ProfileModel effective = XtreamLinkParser.resolve(profile);
      if (effective.type == ProfileType.xtream) {
        final XtreamAccountStatus account = await _xtream.accountStatus(effective);
        emit(
          ConnectionSnapshot(
            phase: account.active ? ConnectionPhase.online : ConnectionPhase.serverIssue,
            title: account.active ? 'Çevrimiçi' : 'Hesap sorunu',
            detail: account.expiryLabel == null
                ? account.statusLabel
                : '${account.statusLabel} • Bitiş ${account.expiryLabel}',
          ),
        );
        return;
      }
      final String url = (profile.m3uUrl ?? '').trim();
      if (url.isEmpty) {
        throw const IptvDataException('M3U bağlantısı boş.');
      }
      await _dio.get<void>(
        url,
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );
      emit(
        const ConnectionSnapshot(
          phase: ConnectionPhase.online,
          title: 'Çevrimiçi',
          detail: 'Oynatma listesi sunucusuna ulaşılıyor.',
        ),
      );
    } catch (_) {
      emit(
        const ConnectionSnapshot(
          phase: ConnectionPhase.serverIssue,
          title: 'Sunucu yanıt vermiyor',
          detail: 'İnternet var, yayın sunucusuna bağlanılamadı.',
        ),
      );
    }
  }
}
