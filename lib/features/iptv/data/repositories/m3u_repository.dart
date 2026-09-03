import 'package:dio/dio.dart';

import '../models/playable_item.dart';
import '../parsers/m3u_parser.dart';

class M3uRepository {
  M3uRepository(this._dio);

  final Dio _dio;

  Future<List<PlayableItem>> download(String playlistUrl) async {
    final String url = playlistUrl.trim();
    if (url.isEmpty) {
      throw const IptvDataException('Profilde geçerli bir M3U bağlantısı bulunmamaktadır.');
    }

    final Response<String> response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(minutes: 3),
      ),
    );

    final int status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw IptvDataException(
        'Oynatma listesi sunucusu $status yanıtı döndürdü. Lütfen bağlantıyı kontrol ediniz.',
      );
    }

    final String body = response.data ?? '';
    if (!body.contains('#EXTINF')) {
      throw const IptvDataException(
        'Oynatma listesi okunamadı. Bağlantı geçerli bir M3U dosyası döndürmüyor.',
      );
    }

    final List<PlayableItem> items = M3uParser.parse(body);
    if (items.isEmpty) {
      throw const IptvDataException('Oynatma listesinde yayınlanabilir kanal bulunamadı.');
    }
    return items;
  }
}

class IptvDataException implements Exception {
  const IptvDataException(this.message);

  final String message;

  @override
  String toString() => message;
}
