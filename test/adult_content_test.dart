import 'package:falconiptv/features/catalog/presentation/cubit/catalog_cubit.dart';
import 'package:falconiptv/features/iptv/data/models/playable_item.dart';
import 'package:falconiptv/features/settings/domain/adult_content_policy.dart';
import 'package:flutter_test/flutter_test.dart';

PlayableItem _item(String title, String category) {
  return PlayableItem(
    id: title,
    title: title,
    category: category,
    streamUrl: 'http://server.invalid/$title',
  );
}

void main() {
  test('yetişkin kategorileri farklı yazımlarda tanınır', () {
    expect(AdultContentPolicy.isAdult('XXX ADULT'), isTrue);
    expect(AdultContentPolicy.isAdult('TR| YETİŞKİN'), isTrue);
    expect(AdultContentPolicy.isAdult('EROTİK FİLMLER'), isTrue);
    expect(AdultContentPolicy.isAdult('18+ CHANNELS'), isTrue);
    expect(AdultContentPolicy.isAdult('TR| ULUSAL'), isFalse);
    expect(AdultContentPolicy.isAdult('●| YENİ EKLENEN FİLMLER'), isFalse);
  });

  test('başlığında XXX geçen içerik yetişkin sayılır', () {
    expect(
      AdultContentPolicy.isAdultContent(
        category: 'TR| DRAM',
        title: 'XXX Paylastigimiz Sırlar',
      ),
      isTrue,
    );
    expect(
      AdultContentPolicy.isAdultContent(
        category: 'TR| DRAM',
        title: 'Paylaştığımız Sırlar',
      ),
      isFalse,
    );
  });

  test('kilitliyken yetişkin içerik Tümü listesinde görünmez', () {
    final CatalogLoaded locked = CatalogLoaded(
      categories: const <String>['Tümü', 'TR| ULUSAL', 'XXX ADULT'],
      items: <PlayableItem>[
        _item('TRT 1', 'TR| ULUSAL'),
        _item('Gizli Kanal', 'XXX ADULT'),
      ],
      selectedCategory: 'Tümü',
      adultUnlocked: false,
    );

    expect(locked.visibleItems.map((PlayableItem i) => i.title), <String>['TRT 1']);
    expect(
      locked.copyWith(adultUnlocked: true).visibleItems.length,
      2,
    );
  });
}
