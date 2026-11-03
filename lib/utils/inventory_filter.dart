import '../models/stock_item.dart';

enum QuantitySort { newest, ascending, descending }

/// Advanced search applied to a freshly retrieved Firestore snapshot.
///
/// Every active control is combined with AND:
///   keyword (itemName OR sku, partial, case-insensitive)
///   AND category (unless "All")
///   AND low stock (quantity <= reorderLevel) when enabled.
/// The visible result is then sorted by quantity if requested.
class InventoryFilter {
  final String keyword;
  final String? category; // null means "All"
  final bool lowStockOnly;
  final QuantitySort sort;

  const InventoryFilter({
    this.keyword = '',
    this.category,
    this.lowStockOnly = false,
    this.sort = QuantitySort.newest,
  });

  static const InventoryFilter none = InventoryFilter();

  bool get hasActiveFilters =>
      keyword.trim().isNotEmpty || category != null || lowStockOnly;

  bool get isDefault => !hasActiveFilters && sort == QuantitySort.newest;

  InventoryFilter copyWith({
    String? keyword,
    String? category,
    bool clearCategory = false,
    bool? lowStockOnly,
    QuantitySort? sort,
  }) {
    return InventoryFilter(
      keyword: keyword ?? this.keyword,
      category: clearCategory ? null : (category ?? this.category),
      lowStockOnly: lowStockOnly ?? this.lowStockOnly,
      sort: sort ?? this.sort,
    );
  }

  bool matches(StockItem item) {
    final k = keyword.trim().toLowerCase();
    if (k.isNotEmpty &&
        !item.itemName.toLowerCase().contains(k) &&
        !item.sku.toLowerCase().contains(k)) {
      return false;
    }
    if (category != null && item.category != category) return false;
    if (lowStockOnly && !item.isLowStock) return false;
    return true;
  }

  List<StockItem> apply(List<StockItem> items) {
    final result = items.where(matches).toList();
    switch (sort) {
      case QuantitySort.ascending:
        result.sort((a, b) {
          final c = a.quantity.compareTo(b.quantity);
          return c != 0 ? c : a.sku.compareTo(b.sku);
        });
      case QuantitySort.descending:
        result.sort((a, b) {
          final c = b.quantity.compareTo(a.quantity);
          return c != 0 ? c : a.sku.compareTo(b.sku);
        });
      case QuantitySort.newest:
        break; // keep Firestore order (newest first)
    }
    return result;
  }
}
