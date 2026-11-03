import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory_manager/utils/inventory_filter.dart';
import 'package:stock_inventory_manager/utils/validators.dart';

import 'fake_inventory_repository.dart';

void main() {
  group('Validators', () {
    test('SKU', () {
      expect(StockValidators.sku('STK-101'), isNull);
      expect(StockValidators.sku(' STK-999 '), isNull);
      for (final bad in ['', 'STK-1', 'STK-1011', 'ABC-101', 'STK101']) {
        expect(StockValidators.sku(bad), isNotNull, reason: bad);
      }
    });
    test('Item name trimmed, >= 3 chars', () {
      expect(StockValidators.itemName('Pen'), isNull);
      expect(StockValidators.itemName('  ab  '), isNotNull);
      expect(StockValidators.itemName(''), isNotNull);
    });
    test('Category required', () {
      expect(StockValidators.category(null), 'Please select a category');
      expect(StockValidators.category('Electronics'), isNull);
    });
    test('Quantity / reorder level: whole numbers >= 0', () {
      expect(StockValidators.quantity('0'), isNull);
      expect(StockValidators.quantity('25'), isNull);
      expect(StockValidators.quantity('-1'), contains('negative'));
      expect(StockValidators.quantity('4.5'), contains('whole number'));
      expect(StockValidators.reorderLevel('abc'), isNotNull);
      expect(StockValidators.reorderLevel(''), isNotNull);
    });
    test('Unit price > 0', () {
      expect(StockValidators.unitPrice('19.90'), isNull);
      expect(StockValidators.unitPrice('0'), contains('greater than'));
      expect(StockValidators.unitPrice('-5'), contains('greater than'));
      expect(StockValidators.unitPrice(''), contains('required'));
      expect(StockValidators.unitPrice('abc'), isNotNull);
    });
  });

  group('Advanced search (brief acceptance outcomes)', () {
    List<String> skus(InventoryFilter f) =>
        f.apply(acceptanceItems).map((i) => i.sku).toList();

    test('"mouse" + Electronics + Low stock -> only STK-103', () {
      expect(
        skus(const InventoryFilter(
            keyword: 'mouse', category: 'Electronics', lowStockOnly: true)),
        ['STK-103'],
      );
    });
    test('"STK-102" with All / all stock -> Notebook (case-insensitive partial)', () {
      expect(skus(const InventoryFilter(keyword: 'STK-102')), ['STK-102']);
      expect(skus(const InventoryFilter(keyword: 'stk-10')).length, 3);
      expect(skus(const InventoryFilter(keyword: 'NOTE')), ['STK-102']);
    });
    test('Low stock uses quantity <= reorderLevel', () {
      expect(skus(const InventoryFilter(lowStockOnly: true)), ['STK-101', 'STK-103']);
    });
    test('Sort by quantity ascending / descending', () {
      expect(skus(const InventoryFilter(sort: QuantitySort.ascending)),
          ['STK-103', 'STK-101', 'STK-102']);
      expect(skus(const InventoryFilter(sort: QuantitySort.descending)),
          ['STK-102', 'STK-101', 'STK-103']);
    });
    test('Cleared filter returns full list', () {
      expect(skus(InventoryFilter.none).length, 3);
    });
  });
}
