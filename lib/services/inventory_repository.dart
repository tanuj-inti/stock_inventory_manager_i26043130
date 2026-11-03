import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stock_item.dart';

/// Abstraction over the inventory data source. The app uses
/// [FirestoreInventoryRepository]; widget tests can supply a fake.
abstract class InventoryRepository {
  /// Live stream of every document in `stockItems`, newest first.
  Stream<List<StockItem>> watchItems();

  /// Writes one item and completes only after Firestore acknowledges the
  /// write. Returns the auto-generated document ID.
  Future<String> addItem(StockItem item);
}

class FirestoreInventoryRepository implements InventoryRepository {
  static const String collectionName = 'stockItems';

  /// How long to wait for the server to acknowledge a write before
  /// reporting a failure to the user (instead of spinning forever).
  static const Duration writeTimeout = Duration(seconds: 20);

  final CollectionReference<Map<String, dynamic>> _collection;

  FirestoreInventoryRepository({FirebaseFirestore? firestore})
      : _collection = (firestore ?? FirebaseFirestore.instance)
            .collection(collectionName);

  @override
  Stream<List<StockItem>> watchItems() {
    return _collection.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => StockItem.fromMap(doc.id, doc.data()))
          .toList();
      // A just-saved item can briefly have a pending (null) server
      // timestamp; treat it as "now" so it sorts to the top.
      items.sort((a, b) {
        final ad = a.createdAt ?? DateTime.now();
        final bd = b.createdAt ?? DateTime.now();
        return bd.compareTo(ad); // newest first
      });
      return items;
    });
  }

  @override
  Future<String> addItem(StockItem item) async {
    final ref = await _collection.add({
      ...item.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    }).timeout(writeTimeout);
    return ref.id;
  }
}
