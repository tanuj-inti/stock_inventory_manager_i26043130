import 'dart:async';

import 'package:stock_inventory_manager/models/stock_item.dart';
import 'package:stock_inventory_manager/services/inventory_repository.dart';

/// In-memory stand-in for Firestore, used only by tests.
class FakeInventoryRepository implements InventoryRepository {
  final List<StockItem> _items = [];
  final _controller = StreamController<List<StockItem>>.broadcast();
  final List<Map<String, dynamic>> writes = [];
  bool failWrites = false;
  int _nextId = 1;

  FakeInventoryRepository([List<StockItem> seed = const []]) {
    _items.addAll(seed);
  }

  @override
  Stream<List<StockItem>> watchItems() async* {
    yield List.of(_items.reversed);
    yield* _controller.stream;
  }

  @override
  Future<String> addItem(StockItem item) async {
    if (failWrites) throw Exception('permission-denied');
    writes.add(item.toMap());
    final id = 'doc${_nextId++}';
    _items.add(StockItem.fromMap(id, {...item.toMap(), 'createdAt': DateTime.now()}));
    _controller.add(List.of(_items.reversed));
    return id;
  }
}

const acceptanceItems = [
  StockItem(id: 'a', sku: 'STK-101', itemName: 'USB C Cable', category: 'Electronics',
      quantity: 4, unitPrice: 19.90, reorderLevel: 5),
  StockItem(id: 'b', sku: 'STK-102', itemName: 'Notebook', category: 'Stationery',
      quantity: 25, unitPrice: 4.50, reorderLevel: 10),
  StockItem(id: 'c', sku: 'STK-103', itemName: 'Wireless Mouse', category: 'Electronics',
      quantity: 1, unitPrice: 35.00, reorderLevel: 3),
];
