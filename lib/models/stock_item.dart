/// Data model for one document in the Firestore `stockItems` collection.
///
/// Field names and types match the required schema exactly:
///   sku (String), itemName (String), category (String), quantity (int),
///   unitPrice (double), reorderLevel (int), createdAt (Timestamp).
class StockItem {
  /// The four permitted categories (also used by the form and search filter).
  static const List<String> categories = [
    'Electronics',
    'Stationery',
    'Hardware',
    'Grocery',
  ];

  final String? id; // Firestore auto-generated document ID
  final String sku;
  final String itemName;
  final String category;
  final int quantity;
  final double unitPrice;
  final int reorderLevel;
  final DateTime? createdAt;

  const StockItem({
    this.id,
    required this.sku,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.reorderLevel,
    this.createdAt,
  });

  /// Low stock rule from the brief: quantity <= reorderLevel.
  bool get isLowStock => quantity <= reorderLevel;

  /// Total value of this line of stock in RM.
  double get stockValue => quantity * unitPrice;

  /// Map written to Firestore. `createdAt` is added by the repository as a
  /// server timestamp, so it is not part of this map.
  Map<String, dynamic> toMap() => {
        'sku': sku,
        'itemName': itemName,
        'category': category,
        'quantity': quantity, // int
        'unitPrice': unitPrice, // double (Firestore Number)
        'reorderLevel': reorderLevel, // int
      };

  /// Builds an item from a Firestore document. Parsing is defensive so one
  /// badly formed document cannot crash the inventory screen.
  factory StockItem.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return StockItem(
      id: id,
      sku: (data['sku'] ?? '').toString(),
      itemName: (data['itemName'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 0,
      // Firestore returns a Timestamp; anything with toDate() is accepted.
      createdAt: created == null
          ? null
          : (created is DateTime
              ? created
              : (created as dynamic).toDate() as DateTime),
    );
  }
}
