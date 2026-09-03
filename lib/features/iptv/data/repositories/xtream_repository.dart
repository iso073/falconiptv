import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../profile/data/models/profile_model.dart';
import '../models/playable_item.dart';
import '../models/series_details.dart';
import 'm3u_repository.dart';

class XtreamRepository {
  XtreamRepository(this._dio);

  final Dio _dio;

  String _base(ProfileModel profile) {
    final String raw = (profile.serverUrl ?? '').trim();
    if (raw.isEmpty) {
      throw const IptvDataException('Profilde geçerli bir sunucu adresi bulunmamaktadır.');
    }
    final String withScheme = raw.startsWith('http') ? raw : 'http://$raw';
    return withScheme.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _playerApi(ProfileModel profile, Map<String, String> extra) {
    return Uri.parse('${_base(profile)}/player_api.php').replace(
      queryParameters: <String, String>{
        'username': profile.username ?? '',
        'password': profile.password ?? '',
        ...extra,
      },
    );
  }

  Future<dynamic> _request(ProfileModel profile, Map<String, String> extra) async {
    final Response<dynamic> response = await _dio.getUri<dynamic>(
      _playerApi(profile, extra),
      options: Options(responseType: ResponseType.plain),
    );
    final int status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw IptvDataException(
        'Xtream sunucusu $status yanıtı döndürdü. Lütfen sunucu bilgilerinizi kontrol ediniz.',
      );
    }
    final dynamic raw = response.data;
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return const <dynamic>[];
      }
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        throw const IptvDataException(
          'Xtream sunucusundan beklenen veri alınamadı. Lütfen kullanıcı bilgilerinizi doğrulayınız.',
        );
      }
    }
    return raw;
  }

  Future<List<Map<String, dynamic>>> _list(ProfileModel profile, String action) async {
    final dynamic data = await _request(profile, <String, String>{'action': action});
    if (data is List) {
      return data.map(_asMap).toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, String>> _categories(ProfileModel profile, String action) async {
    final List<Map<String, dynamic>> rows = await _list(profile, action);
    return <String, String>{
      for (final Map<String, dynamic> row in rows)
        '${row['category_id']}': '${row['category_name'] ?? 'Diğer'}',
    };
  }

  Future<XtreamAccountStatus> accountStatus(ProfileModel profile) async {
    final dynamic data = await _request(profile, const <String, String>{});
    final Map<String, dynamic> auth = _asMap(_asMap(data)['user_info']);
    final String raw = '${auth['status'] ?? auth['auth'] ?? ''}'.toLowerCase();
    final bool active = raw != '0' && raw != 'expired' && raw != 'banned' && raw != 'disabled';
    return XtreamAccountStatus(
      active: active,
      statusLabel: active ? 'Hesap etkin' : 'Hesap doğrulanamadı',
      expiryLabel: _formatExpiry(auth['exp_date']),
    );
  }

  Future<void> verifyAccount(ProfileModel profile) async {
    final XtreamAccountStatus status = await accountStatus(profile);
    if (!status.active) {
      throw const IptvDataException(
        'Xtream hesabı doğrulanamadı. Kullanıcı bilgilerinizi kontrol ediniz.',
      );
    }
  }

  Future<CatalogSnapshot> getLiveStreams(ProfileModel profile) async {
    final Map<String, String> categories = await _categories(profile, 'get_live_categories');
    final List<Map<String, dynamic>> rows = await _list(profile, 'get_live_streams');
    final String base = _base(profile);
    final List<PlayableItem> items = <PlayableItem>[];

    for (final Map<String, dynamic> row in rows) {
      final String id = '${row['stream_id'] ?? ''}';
      if (id.isEmpty) {
        continue;
      }
      final String category = categories['${row['category_id']}'] ?? 'Diğer';
      items.add(
        PlayableItem(
          id: id,
          title: '${row['name'] ?? 'Kanal'}',
          subtitle: category,
          category: category,
          logoUrl: row['stream_icon'] as String?,
          streamUrl: '$base/live/${profile.username}/${profile.password}/$id.m3u8',
        ),
      );
    }
    return _snapshot(items);
  }

  Future<CatalogSnapshot> getVodStreams(ProfileModel profile) async {
    final Map<String, String> categories = await _categories(profile, 'get_vod_categories');
    final List<Map<String, dynamic>> rows = await _list(profile, 'get_vod_streams');
    final String base = _base(profile);
    final List<PlayableItem> items = <PlayableItem>[];

    for (final Map<String, dynamic> row in rows) {
      final String id = '${row['stream_id'] ?? ''}';
      if (id.isEmpty) {
        continue;
      }
      final String category = categories['${row['category_id']}'] ?? 'Diğer';
      final String extension = '${row['container_extension'] ?? 'mp4'}';
      items.add(
        PlayableItem(
          id: id,
          title: '${row['name'] ?? 'Film'}',
          subtitle: extension.toUpperCase(),
          category: category,
          logoUrl: row['stream_icon'] as String?,
          streamUrl: '$base/movie/${profile.username}/${profile.password}/$id.$extension',
          kind: PlayableKind.vod,
          addedAt: _epochSeconds(row['added']),
        ),
      );
    }
    return _snapshot(items);
  }

  Future<CatalogSnapshot> getSeries(ProfileModel profile) async {
    final Map<String, String> categories = await _categories(profile, 'get_series_categories');
    final List<Map<String, dynamic>> rows = await _list(profile, 'get_series');
    final List<PlayableItem> items = <PlayableItem>[];

    for (final Map<String, dynamic> row in rows) {
      final String id = '${row['series_id'] ?? ''}';
      if (id.isEmpty) {
        continue;
      }
      final String category = categories['${row['category_id']}'] ?? 'Diğer';
      items.add(
        PlayableItem(
          id: id,
          title: '${row['name'] ?? 'Dizi'}',
          subtitle: category,
          category: category,
          logoUrl: (row['cover'] ?? row['stream_icon']) as String?,
          streamUrl: '',
          kind: PlayableKind.series,
          addedAt: _epochSeconds(row['last_modified'] ?? row['added']),
        ),
      );
    }
    return _snapshot(items);
  }

  Future<PlayableItem?> resolveFirstEpisode(ProfileModel profile, PlayableItem series) async {
    final SeriesDetails details = await getSeriesDetails(profile, series);
    if (details.seasons.isEmpty || details.seasons.first.episodes.isEmpty) {
      return null;
    }
    return details.seasons.first.episodes.first;
  }

  Future<SeriesDetails> getSeriesDetails(ProfileModel profile, PlayableItem series) async {
    final dynamic data = await _request(profile, <String, String>{
      'action': 'get_series_info',
      'series_id': series.id,
    });
    final Map<String, dynamic> info = _asMap(data);
    final dynamic episodes = info['episodes'];
    final List<SeriesSeason> seasons = <SeriesSeason>[];

    void addSeason(String id, List<dynamic> rows) {
      final List<PlayableItem> items = <PlayableItem>[];
      for (final dynamic row in rows) {
        final Map<String, dynamic> episode = _asMap(row);
        final String episodeId = '${episode['id'] ?? ''}';
        if (episodeId.isEmpty) {
          continue;
        }
        final String extension = '${episode['container_extension'] ?? 'mp4'}';
        final String episodeTitle = '${episode['title'] ?? episode['container_extension'] ?? 'Bölüm'}';
        items.add(
          PlayableItem(
            id: episodeId,
            title: episodeTitle.contains(series.title) ? episodeTitle : '${series.title} • $episodeTitle',
            subtitle: 'Sezon $id',
            category: series.category,
            logoUrl: series.logoUrl,
            streamUrl: '${_base(profile)}/series/${profile.username}/${profile.password}/$episodeId.$extension',
            kind: PlayableKind.series,
            seriesId: series.id,
          ),
        );
      }
      if (items.isNotEmpty) {
        seasons.add(SeriesSeason(id: id, title: 'Sezon $id', episodes: items));
      }
    }

    if (episodes is Map) {
      final List<dynamic> keys = episodes.keys.toList()
        ..sort((a, b) {
          final int left = int.tryParse('$a') ?? 0;
          final int right = int.tryParse('$b') ?? 0;
          return left.compareTo(right);
        });
      for (final dynamic key in keys) {
        final dynamic season = episodes[key];
        if (season is List) {
          addSeason('$key', season);
        }
      }
    } else if (episodes is List) {
      addSeason('1', episodes);
    }

    return SeriesDetails(series: series, seasons: seasons);
  }

  Future<List<StreamSubtitle>> getVodSubtitles(ProfileModel profile, PlayableItem item) async {
    if (item.kind == PlayableKind.live) {
      return const <StreamSubtitle>[];
    }
    final bool isSeries = item.kind == PlayableKind.series;
    final dynamic data = await _request(profile, <String, String>{
      'action': isSeries ? 'get_series_info' : 'get_vod_info',
      if (isSeries) 'series_id': item.seriesId ?? item.id,
      if (!isSeries) 'vod_id': item.id,
    });
    final Map<String, dynamic> info = _asMap(_asMap(data)['info']);
    final List<StreamSubtitle> tracks = <StreamSubtitle>[];

    void addTrack(String label, String url) {
      final String trimmed = url.trim();
      if (trimmed.isEmpty) {
        return;
      }
      tracks.add(StreamSubtitle(label: label, url: trimmed));
    }

    final dynamic subtitles = info['subtitles'] ?? _asMap(data)['subtitles'];
    if (subtitles is String) {
      addTrack('Altyazı', subtitles);
    } else if (subtitles is List) {
      for (final dynamic row in subtitles) {
        if (row is String) {
          addTrack('Altyazı', row);
        } else if (row is Map) {
          final Map<String, dynamic> map = _asMap(row);
          addTrack(
            '${map['language'] ?? map['title'] ?? map['label'] ?? 'Altyazı'}',
            '${map['url'] ?? map['file'] ?? map['src'] ?? ''}',
          );
        }
      }
    }
    return tracks;
  }

  Future<List<EpgListing>> getShortEpg(
    ProfileModel profile,
    String streamId,
    String channelName,
  ) async {
    final dynamic data = await _request(profile, <String, String>{
      'action': 'get_short_epg',
      'stream_id': streamId,
      'limit': '6',
    });
    final dynamic listings = _asMap(data)['epg_listings'];
    if (listings is! List) {
      return const <EpgListing>[];
    }
    return listings.map(_asMap).map((Map<String, dynamic> row) {
      return EpgListing(
        channelName: channelName,
        title: _decodeMaybeBase64('${row['title'] ?? ''}'),
        timeRange: _timeRange('${row['start'] ?? ''}', '${row['end'] ?? ''}'),
        category: channelName,
      );
    }).toList();
  }

  String? _formatExpiry(dynamic value) {
    if (value == null) {
      return null;
    }
    final DateTime? parsed = value is int
        ? DateTime.fromMillisecondsSinceEpoch(value * 1000)
        : DateTime.tryParse('$value'.replaceFirst(' ', 'T'));
    if (parsed == null) {
      final String text = '$value';
      return text.isEmpty ? null : text;
    }
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}';
  }

  CatalogSnapshot _snapshot(List<PlayableItem> items) {
    final List<String> used = <String>[];
    for (final PlayableItem item in items) {
      if (!used.contains(item.category)) {
        used.add(item.category);
      }
    }
    used.sort();
    return CatalogSnapshot(categories: <String>['Tümü', ...used], items: items);
  }

  DateTime? _epochSeconds(dynamic value) {
    if (value == null) {
      return null;
    }
    final int? seconds = value is int ? value : int.tryParse('$value');
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  Map<String, dynamic> _asMap(dynamic row) {
    if (row is Map<String, dynamic>) {
      return row;
    }
    if (row is Map) {
      return Map<String, dynamic>.from(row);
    }
    return <String, dynamic>{};
  }

  String _timeRange(String start, String end) {
    final String from = _shortTime(start);
    final String to = _shortTime(end);
    if (from.isEmpty && to.isEmpty) {
      return '';
    }
    return '$from - $to';
  }

  String _shortTime(String value) {
    final DateTime? parsed = DateTime.tryParse(value.replaceFirst(' ', 'T'));
    if (parsed == null) {
      return value;
    }
    final String hour = parsed.hour.toString().padLeft(2, '0');
    final String minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _decodeMaybeBase64(String value) {
    if (value.isEmpty) {
      return value;
    }
    try {
      final String decoded = utf8.decode(base64Decode(value));
      if (decoded.trim().isNotEmpty) {
        return decoded;
      }
    } catch (_) {}
    return value;
  }
}
