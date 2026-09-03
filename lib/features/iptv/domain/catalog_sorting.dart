import '../../settings/domain/adult_content_policy.dart';
import '../data/models/playable_item.dart';

/// Ordering rules shared by every catalog section: Turkish groups are listed
/// first, on-demand content is listed newest first, and adult groups stay last.
abstract final class CatalogSorting {
  static const String allCategory = 'Tümü';

  static const List<String> _turkishMarkers = <String>[
    'turk',
    'turkiye',
    'turkey',
    'turkish',
    'yerli',
  ];

  static const List<String> _recentlyAddedMarkers = <String>[
    'yeni eklenen',
    'son eklenen',
    'yeni cikan',
    'yeni gelen',
    'recently added',
    'newly added',
    'new added',
    'latest added',
    'new release',
  ];

  static String normalize(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in value.runes) {
      final String char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        'İ' || 'I' || 'ı' || 'i' => 'i',
        'Ü' || 'ü' => 'u',
        'Ö' || 'ö' => 'o',
        'Ş' || 'ş' => 's',
        'Ç' || 'ç' => 'c',
        'Ğ' || 'ğ' => 'g',
        _ => char.toLowerCase(),
      });
    }
    return buffer.toString().trim();
  }

  static final RegExp _turkishCountryCode = RegExp(r'(^|[\s|:_-])tr($|[\s|:_-])');

  static bool isTurkish(String category) {
    final String normalized = normalize(category);
    if (normalized.startsWith('tr|') ||
        normalized.startsWith('tr ') ||
        normalized.startsWith('tr-') ||
        normalized.startsWith('tr_') ||
        normalized.startsWith('tr:') ||
        normalized == 'tr') {
      return true;
    }
    if (_turkishCountryCode.hasMatch(normalized)) {
      return true;
    }
    return _turkishMarkers.any(normalized.contains);
  }

  static bool isRecentlyAdded(String category) {
    final String normalized = normalize(category);
    return _recentlyAddedMarkers.any(normalized.contains);
  }

  static bool isAdult(String category) => AdultContentPolicy.isAdult(category);

  static List<String> sortCategories(List<String> categories) {
    final List<String> rest = categories.where((c) => c != allCategory).toList();
    int byName(String a, String b) => normalize(a).compareTo(normalize(b));

    final List<String> adult = rest.where(isAdult).toList()..sort(byName);
    final List<String> nonAdult = rest.where((c) => !isAdult(c)).toList();
    final List<String> turkish = nonAdult.where(isTurkish).toList();
    final List<String> others = nonAdult.where((c) => !isTurkish(c)).toList();

    return <String>[
      if (categories.contains(allCategory)) allCategory,
      ..._recentThenName(turkish, byName),
      ..._recentThenName(others, byName),
      ...adult,
    ];
  }

  static List<String> _recentThenName(List<String> categories, int Function(String, String) byName) {
    final List<String> recent = categories.where(isRecentlyAdded).toList()..sort(byName);
    final List<String> rest = categories.where((c) => !isRecentlyAdded(c)).toList()..sort(byName);
    return <String>[...recent, ...rest];
  }

  static List<PlayableItem> turkishFirst(List<PlayableItem> items) {
    final List<PlayableItem> turkish = <PlayableItem>[];
    final List<PlayableItem> others = <PlayableItem>[];
    final List<PlayableItem> adult = <PlayableItem>[];
    for (final PlayableItem item in items) {
      if (isAdult(item.category)) {
        adult.add(item);
      } else if (isTurkish(item.category)) {
        turkish.add(item);
      } else {
        others.add(item);
      }
    }
    return <PlayableItem>[...turkish, ...others, ...adult];
  }

  static List<PlayableItem> newestFirst(List<PlayableItem> items) {
    final List<PlayableItem> turkish = <PlayableItem>[];
    final List<PlayableItem> others = <PlayableItem>[];
    final List<PlayableItem> adult = <PlayableItem>[];
    for (final PlayableItem item in items) {
      if (isAdult(item.category)) {
        adult.add(item);
      } else if (isTurkish(item.category)) {
        turkish.add(item);
      } else {
        others.add(item);
      }
    }
    return <PlayableItem>[
      ..._newestFirstGroup(turkish),
      ..._newestFirstGroup(others),
      ..._newestFirstGroup(adult),
    ];
  }

  static List<PlayableItem> _newestFirstGroup(List<PlayableItem> items) {
    final List<PlayableItem> dated =
        items.where((PlayableItem item) => item.addedAt != null).toList()
          ..sort((a, b) => b.addedAt!.compareTo(a.addedAt!));
    final List<PlayableItem> undated =
        items.where((PlayableItem item) => item.addedAt == null).toList();
    return <PlayableItem>[...dated, ...undated];
  }
}
