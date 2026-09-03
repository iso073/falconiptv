part of 'catalog_cubit.dart';

sealed class CatalogState {
  const CatalogState();
}

class CatalogInitial extends CatalogState {
  const CatalogInitial();
}

class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

class CatalogLoaded extends CatalogState {
  const CatalogLoaded({
    required this.categories,
    required this.items,
    required this.selectedCategory,
    required this.adultUnlocked,
  });

  final List<String> categories;
  final List<PlayableItem> items;
  final String selectedCategory;
  final bool adultUnlocked;

  List<PlayableItem> get visibleItems {
    final Iterable<PlayableItem> allowed = adultUnlocked
        ? items
        : items.where((PlayableItem item) => !AdultContentPolicy.isAdult(item.category));
    if (selectedCategory == 'Tümü') {
      return allowed.toList();
    }
    return allowed
        .where((PlayableItem item) => item.category == selectedCategory)
        .toList();
  }

  CatalogLoaded copyWith({String? selectedCategory, bool? adultUnlocked}) {
    return CatalogLoaded(
      categories: categories,
      items: items,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      adultUnlocked: adultUnlocked ?? this.adultUnlocked,
    );
  }
}

class CatalogError extends CatalogState {
  const CatalogError(this.message);

  final String message;
}
