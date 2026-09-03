import '../../../profile/data/models/profile_model.dart';
import '../../domain/catalog_sorting.dart';
import '../../domain/xtream_link_parser.dart';
import '../models/playable_item.dart';
import '../models/series_details.dart';
import '../parsers/m3u_parser.dart';
import 'm3u_repository.dart';
import 'xtream_repository.dart';

enum CatalogSection { live, movies, series }

class IptvCatalogRepository {
  IptvCatalogRepository({
    required M3uRepository m3uRepository,
    required XtreamRepository xtreamRepository,
  })  : _m3u = m3uRepository,
        _xtream = xtreamRepository;

  final M3uRepository _m3u;
  final XtreamRepository _xtream;

  final Map<String, List<PlayableItem>> _m3uCache = <String, List<PlayableItem>>{};

  Future<CatalogSnapshot> loadSection(
    ProfileModel? profile,
    CatalogSection section, {
    bool forceRefresh = false,
  }) async {
    final ProfileModel active = XtreamLinkParser.resolve(_requireProfile(profile));

    if (active.type == ProfileType.xtream) {
      final CatalogSnapshot snapshot = await switch (section) {
        CatalogSection.live => _xtream.getLiveStreams(active),
        CatalogSection.movies => _xtream.getVodStreams(active),
        CatalogSection.series => _xtream.getSeries(active),
      };
      return _sorted(snapshot, section);
    }

    final List<PlayableItem> playlist = await _m3uPlaylist(active, forceRefresh: forceRefresh);
    if (section != CatalogSection.live) {
      throw const IptvDataException(
        'M3U oynatma listeleri yalnızca canlı yayın kanallarını içermektedir.',
      );
    }
    return _sorted(
      CatalogSnapshot(
        categories: M3uParser.categoriesOf(playlist),
        items: playlist,
      ),
      section,
    );
  }

  CatalogSnapshot _sorted(CatalogSnapshot snapshot, CatalogSection section) {
    return CatalogSnapshot(
      categories: CatalogSorting.sortCategories(snapshot.categories),
      items: section == CatalogSection.live
          ? CatalogSorting.turkishFirst(snapshot.items)
          : CatalogSorting.newestFirst(snapshot.items),
    );
  }

  Future<List<EpgListing>> loadEpg(ProfileModel? profile) async {
    final ProfileModel active = XtreamLinkParser.resolve(_requireProfile(profile));
    if (active.type != ProfileType.xtream) {
      throw const IptvDataException(
        'Yayın akışı bilgisi yalnızca Xtream Codes profillerinde sunulmaktadır.',
      );
    }

    final CatalogSnapshot live = await _xtream.getLiveStreams(active);
    final List<EpgListing> listings = <EpgListing>[];
    for (final PlayableItem channel in live.items.take(8)) {
      listings.addAll(await _xtream.getShortEpg(active, channel.id, channel.title));
    }
    if (listings.isEmpty) {
      throw const IptvDataException(
        'Sunucu bu hesap için yayın akışı verisi döndürmedi.',
      );
    }
    return listings;
  }

  Future<PlayableItem> resolvePlayable(ProfileModel? profile, PlayableItem item) async {
    if (!item.isSeriesShell) {
      return item;
    }
    final ProfileModel active = XtreamLinkParser.resolve(_requireProfile(profile));
    final PlayableItem? episode = await _xtream.resolveFirstEpisode(active, item);
    if (episode == null) {
      throw const IptvDataException('Bu dizi için oynatılabilir bölüm bulunamadı.');
    }
    return episode;
  }

  Future<SeriesDetails> loadSeriesDetails(ProfileModel? profile, PlayableItem series) {
    return _xtream.getSeriesDetails(XtreamLinkParser.resolve(_requireProfile(profile)), series);
  }

  Future<List<StreamSubtitle>> loadSubtitles(ProfileModel? profile, PlayableItem item) async {
    final ProfileModel active = XtreamLinkParser.resolve(_requireProfile(profile));
    if (active.type != ProfileType.xtream) {
      return const <StreamSubtitle>[];
    }
    try {
      return await _xtream.getVodSubtitles(active, item);
    } catch (_) {
      return const <StreamSubtitle>[];
    }
  }

  Future<List<PlayableItem>> search(ProfileModel? profile, String query) async {
    final ProfileModel active = XtreamLinkParser.resolve(_requireProfile(profile));
    final String needle = query.trim().toLowerCase();
    if (needle.length < 2) {
      return const <PlayableItem>[];
    }

    final List<PlayableItem> matches = <PlayableItem>[];
    Future<void> addSection(CatalogSection section) async {
      try {
        final CatalogSnapshot snapshot = await loadSection(active, section);
        for (final PlayableItem item in snapshot.items) {
          if (item.title.toLowerCase().contains(needle) ||
              item.category.toLowerCase().contains(needle)) {
            matches.add(item);
          }
        }
      } catch (_) {}
    }

    await addSection(CatalogSection.live);
    if (active.type == ProfileType.xtream) {
      await addSection(CatalogSection.movies);
      await addSection(CatalogSection.series);
    }
    return matches;
  }

  Future<void> validate(ProfileModel profile) async {
    final ProfileModel active = XtreamLinkParser.resolve(profile);
    if (active.type == ProfileType.xtream) {
      await _xtream.verifyAccount(active);
      return;
    }
    await _m3uPlaylist(active, forceRefresh: true);
  }

  void clearCache() => _m3uCache.clear();

  Future<List<PlayableItem>> _m3uPlaylist(
    ProfileModel profile, {
    bool forceRefresh = false,
  }) async {
    final String url = (profile.m3uUrl ?? '').trim();
    if (!forceRefresh && _m3uCache.containsKey(url)) {
      return _m3uCache[url]!;
    }
    final List<PlayableItem> items = await _m3u.download(url);
    _m3uCache[url] = items;
    return items;
  }

  ProfileModel _requireProfile(ProfileModel? profile) {
    if (profile == null) {
      throw const IptvDataException(
        'Aktif profil bulunamadı. Lütfen profil seçim ekranından bir profil belirleyiniz.',
      );
    }
    return profile;
  }
}
