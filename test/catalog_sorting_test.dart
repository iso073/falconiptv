import 'package:falconiptv/features/iptv/data/models/playable_item.dart';
import 'package:falconiptv/features/iptv/domain/catalog_sorting.dart';
import 'package:flutter_test/flutter_test.dart';

PlayableItem _item(String title, String category, {DateTime? addedAt}) {
  return PlayableItem(
    id: title,
    title: title,
    category: category,
    streamUrl: 'http://server.invalid/$title',
    addedAt: addedAt,
    kind: addedAt == null ? PlayableKind.live : PlayableKind.vod,
  );
}

void main() {
  test('kategorilerde Türk grupları başta, diğer ülkeler altında durur', () {
    final List<String> sorted = CatalogSorting.sortCategories(<String>[
      'Tümü',
      'AL| ALBANIA',
      'AT| AUSTRIA',
      'TR| ULUSAL',
      '●| YENİ EKLENEN FİLMLER',
      'Türk Sineması',
      'FR| FRANCE',
      'AR| ARABIA',
    ]);

    expect(sorted.first, 'Tümü');
    expect(sorted.sublist(1, 3), <String>['TR| ULUSAL', 'Türk Sineması']);
    expect(sorted[3], '●| YENİ EKLENEN FİLMLER');
    expect(sorted.sublist(4), <String>['AL| ALBANIA', 'AR| ARABIA', 'AT| AUSTRIA', 'FR| FRANCE']);
  });

  test('yetişkin kategorileri Türk olsa bile en sonda, ülkelerin altında durur', () {
    final List<String> sorted = CatalogSorting.sortCategories(<String>[
      'Tümü',
      'XXX ADULT',
      'TR| ULUSAL',
      'TR| YETİŞKİN',
      'FR| FRANCE',
      'AL| ALBANIA',
      '●| YENİ EKLENEN FİLMLER',
      '18+ CHANNELS',
    ]);

    expect(sorted.first, 'Tümü');
    expect(sorted[1], 'TR| ULUSAL');
    expect(sorted[2], '●| YENİ EKLENEN FİLMLER');
    expect(sorted.sublist(3, 5), <String>['AL| ALBANIA', 'FR| FRANCE']);
    expect(sorted.sublist(5), <String>['18+ CHANNELS', 'TR| YETİŞKİN', 'XXX ADULT']);
  });

  test('yeni eklenen kategorileri farklı yazımlarda tanınır', () {
    expect(CatalogSorting.isRecentlyAdded('●| YENİ EKLENEN DİZİLER'), isTrue);
    expect(CatalogSorting.isRecentlyAdded('SON EKLENENLER'), isTrue);
    expect(CatalogSorting.isRecentlyAdded('RECENTLY ADDED MOVIES'), isTrue);
    expect(CatalogSorting.isRecentlyAdded('TR| ULUSAL'), isFalse);
  });

  test('AUSTRIA gibi içinde tr geçen kategoriler Türk sayılmaz', () {
    expect(CatalogSorting.isTurkish('AT| AUSTRIA'), isFalse);
    expect(CatalogSorting.isTurkish('FR| FRANCE'), isFalse);
    expect(CatalogSorting.isTurkish('TR| HABER'), isTrue);
    expect(CatalogSorting.isTurkish('TR: YERLİ FİLM'), isTrue);
    expect(CatalogSorting.isTurkish('TURKISH MOVIES'), isTrue);
    expect(CatalogSorting.isTurkish('Yerli Diziler'), isTrue);
  });

  test('canlı yayınlarda Türk kanalları listenin başına gelir', () {
    final List<PlayableItem> sorted = CatalogSorting.turkishFirst(<PlayableItem>[
      _item('Albania 1', 'AL| ALBANIA'),
      _item('TRT 1', 'TR| ULUSAL'),
      _item('Arabia 1', 'AR| ARABIA'),
      _item('Show TV', 'TR| ULUSAL'),
    ]);

    expect(
      sorted.map((PlayableItem item) => item.title).toList(),
      <String>['TRT 1', 'Show TV', 'Albania 1', 'Arabia 1'],
    );
  });

  test('canlı yayınlarda yetişkin kanallar Türk olsa bile en sonda durur', () {
    final List<PlayableItem> sorted = CatalogSorting.turkishFirst(<PlayableItem>[
      _item('Adult 1', 'XXX ADULT'),
      _item('TRT 1', 'TR| ULUSAL'),
      _item('Yetişkin TR', 'TR| YETİŞKİN'),
      _item('Albania 1', 'AL| ALBANIA'),
    ]);

    expect(
      sorted.map((PlayableItem item) => item.title).toList(),
      <String>['TRT 1', 'Albania 1', 'Adult 1', 'Yetişkin TR'],
    );
  });

  test('film ve dizilerde TR başta, diğer ülkeler altında, grup içinde yeniler üstte durur', () {
    final List<PlayableItem> sorted = CatalogSorting.newestFirst(<PlayableItem>[
      _item('Eski Film', 'EN| ACTION', addedAt: DateTime(2024, 1, 1)),
      _item('Yeni Fransa', 'FR| DRAMA', addedAt: DateTime(2026, 8, 30)),
      _item('Tarihsiz Yabancı', 'EN| ACTION'),
      _item('Orta Film', 'TR| DRAM', addedAt: DateTime(2025, 6, 1)),
      _item('Yeni Yerli', 'TR| DRAM', addedAt: DateTime(2026, 9, 1)),
      _item('Tarihsiz Yerli', 'TR| DRAM'),
    ]);

    expect(
      sorted.map((PlayableItem item) => item.title).toList(),
      <String>[
        'Yeni Yerli',
        'Orta Film',
        'Tarihsiz Yerli',
        'Yeni Fransa',
        'Eski Film',
        'Tarihsiz Yabancı',
      ],
    );
  });

  test('film listesinde yetişkin içerik ülkelerin altında en sonda durur', () {
    final List<PlayableItem> sorted = CatalogSorting.newestFirst(<PlayableItem>[
      _item('Yeni Adult', 'XXX ADULT', addedAt: DateTime(2026, 8, 30)),
      _item('Yeni Fransa', 'FR| DRAMA', addedAt: DateTime(2026, 8, 29)),
      _item('Eski Yerli', 'TR| DRAM', addedAt: DateTime(2024, 1, 1)),
    ]);

    expect(
      sorted.map((PlayableItem item) => item.title).toList(),
      <String>['Eski Yerli', 'Yeni Fransa', 'Yeni Adult'],
    );
  });
}
