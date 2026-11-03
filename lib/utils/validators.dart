import '../models/stock_item.dart';

/// Field-level validators for the stock entry form. Each returns `null` when
/// the value is valid, or a specific message shown under the field.
class StockValidators {
  StockValidators._();

  static final RegExp skuPattern = RegExp(r'^STK-\d{3}$');
  static final RegExp _wholeNumber = RegExp(r'^\d+$');
  static final RegExp _money = RegExp(r'^\d+(\.\d{1,2})?$');

  static String? sku(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'SKU is required';
    if (!skuPattern.hasMatch(v)) {
      return 'SKU must be STK- followed by three digits, e.g. STK-101';
    }
    return null;
  }

  static String? itemName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Item name is required';
    if (v.length < 3) return 'Item name must be at least 3 characters';
    return null;
  }

  static String? category(String? value) {
    if (value == null || value.isEmpty) return 'Please select a category';
    if (!StockItem.categories.contains(value)) return 'Invalid category';
    return null;
  }

  static String? quantity(String? value) => _nonNegativeInt(value, 'Quantity');

  static String? reorderLevel(String? value) =>
      _nonNegativeInt(value, 'Reorder level');

  static String? unitPrice(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Unit price is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Unit price must be a number, e.g. 19.90';
    if (parsed <= 0) return 'Unit price must be greater than RM 0';
    if (!_money.hasMatch(v)) {
      return 'Use a valid RM amount with up to 2 decimals';
    }
    return null;
  }

  static String? _nonNegativeInt(String? value, String label) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '$label is required';
    final parsed = num.tryParse(v);
    if (parsed == null) return '$label must be a whole number';
    if (parsed < 0) return '$label cannot be negative';
    if (!_wholeNumber.hasMatch(v)) {
      return '$label must be a whole number (no decimals)';
    }
    return null;
  }
}
