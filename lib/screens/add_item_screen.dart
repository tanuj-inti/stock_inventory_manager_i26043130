import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stock_item.dart';
import '../services/inventory_repository.dart';
import '../utils/validators.dart';
import '../widgets/stock_item_card.dart';

/// Task 1 + Task 2: scrollable stock entry form that validates every field
/// and only writes to Firestore when the whole form is valid.
class AddItemScreen extends StatefulWidget {
  final InventoryRepository repository;
  final VoidCallback? onSaved;

  const AddItemScreen({super.key, required this.repository, this.onSaved});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sku = TextEditingController();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _reorder = TextEditingController();
  String? _category;

  bool _saving = false;
  bool _submitted = false; // switch to live validation after first attempt
  String? _errorMessage; // last Firestore write error (form is kept)

  List<TextEditingController> get _controllers =>
      [_sku, _name, _quantity, _price, _reorder];

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke so the progress meter and preview update.
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// How many of the six fields currently pass validation.
  int get _validCount => [
        StockValidators.sku(_sku.text),
        StockValidators.itemName(_name.text),
        StockValidators.category(_category),
        StockValidators.quantity(_quantity.text),
        StockValidators.unitPrice(_price.text),
        StockValidators.reorderLevel(_reorder.text),
      ].where((e) => e == null).length;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });

    // Validation gate: no Firestore write happens unless every field passes.
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      HapticFeedback.mediumImpact();
      _showSnack('Please fix the highlighted fields.', isError: true);
      return;
    }

    final item = StockItem(
      sku: _sku.text.trim(),
      itemName: _name.text.trim(),
      category: _category!,
      quantity: int.parse(_quantity.text.trim()),
      unitPrice: double.parse(_price.text.trim()),
      reorderLevel: int.parse(_reorder.text.trim()),
    );

    setState(() => _saving = true);
    try {
      // Completes only after Firestore acknowledges the write.
      final id = await widget.repository.addItem(item);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _showSnack('Saved ${item.sku} · ${item.itemName} to Firestore (ID: $id)');
      _clearForm();
      widget.onSaved?.call();
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Firestore did not confirm the save in time. Check your connection '
              'and try again — your input has been kept.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Could not save to Firestore: $e\nYour input has been kept.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {
      _category = null;
      _submitted = false;
      _errorMessage = null;
    });
  }

  void _quickFill(List<String> row) {
    setState(() {
      _sku.text = row[0];
      _name.text = row[1];
      _category = row[2];
      _quantity.text = row[3];
      _price.text = row[4];
      _reorder.text = row[5];
      _errorMessage = null;
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? scheme.error : null,
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle,
              color: isError ? scheme.onError : Colors.greenAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ]),
      ));
  }

  // Acceptance test data from the brief (STK-101..103) plus five extra
  // sample items covering every category, for a fast live demonstration.
  static const _sampleData = [
    ['STK-101', 'USB C Cable', 'Electronics', '4', '19.90', '5'],
    ['STK-102', 'Notebook', 'Stationery', '25', '4.50', '10'],
    ['STK-103', 'Wireless Mouse', 'Electronics', '1', '35.00', '3'],
    ['STK-104', 'Claw Hammer', 'Hardware', '12', '28.50', '5'],
    ['STK-105', 'Basmati Rice 5kg', 'Grocery', '3', '32.90', '8'],
    ['STK-106', 'Gel Pen Pack', 'Stationery', '40', '7.80', '15'],
    ['STK-107', 'Cordless Drill', 'Hardware', '2', '189.00', '2'],
    ['STK-108', 'Instant Coffee', 'Grocery', '18', '15.60', '6'],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: 16);

    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      // A Column (not a lazy ListView) so every field is always built and
      // therefore always checked by validate().
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add stock item',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('All fields are required. Saved to Firestore › stockItems.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            _ProgressMeter(done: _validCount, total: 6),
            const SizedBox(height: 18),
            Row(children: [
              Icon(Icons.bolt, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('Quick fill a sample item',
                  style: theme.textTheme.labelLarge),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final row in _sampleData)
                Tooltip(
                  message: '${row[1]} · ${row[2]}',
                  child: ActionChip(
                    avatar: Icon(StockItemCard.iconFor(row[2]), size: 18),
                    label: Text('Fill ${row[0]}'),
                    onPressed: _saving ? null : () => _quickFill(row),
                  ),
                ),
            ]),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('skuField'),
              controller: _sku,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_UpperCaseFormatter()],
              decoration: const InputDecoration(
                labelText: 'SKU',
                hintText: 'STK-101',
                helperText: 'STK- followed by three digits',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              validator: StockValidators.sku,
              textInputAction: TextInputAction.next,
            ),
            gap,
            TextFormField(
              key: const Key('nameField'),
              controller: _name,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'USB C Cable',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: StockValidators.itemName,
              textInputAction: TextInputAction.next,
            ),
            gap,
            DropdownButtonFormField<String>(
              key: const Key('categoryField'),
              initialValue: _category,
              borderRadius: BorderRadius.circular(14),
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    _category == null
                        ? Icons.category_outlined
                        : StockItemCard.iconFor(_category!),
                    key: ValueKey(_category),
                  ),
                ),
              ),
              items: [
                for (final c in StockItem.categories)
                  DropdownMenuItem(
                    value: c,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(StockItemCard.iconFor(c), size: 18),
                      const SizedBox(width: 10),
                      Text(c),
                    ]),
                  ),
              ],
              selectedItemBuilder: (_) => [
                for (final c in StockItem.categories) Text(c),
              ],
              onChanged: _saving ? null : (v) => setState(() => _category = v),
              validator: StockValidators.category,
            ),
            gap,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  key: const Key('quantityField'),
                  controller: _quantity,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    hintText: '0',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: StockValidators.quantity,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('reorderField'),
                  controller: _reorder,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Reorder level',
                    hintText: '0',
                    prefixIcon: Icon(Icons.low_priority),
                  ),
                  validator: StockValidators.reorderLevel,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ]),
            gap,
            TextFormField(
              key: const Key('priceField'),
              controller: _price,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Unit price',
                hintText: '19.90',
                prefixText: 'RM ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: StockValidators.unitPrice,
              onFieldSubmitted: (_) => _save(),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _errorMessage == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        key: const Key('saveError'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.cloud_off,
                                  color: theme.colorScheme.onErrorContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_errorMessage!,
                                    style: TextStyle(
                                        color: theme
                                            .colorScheme.onErrorContainer)),
                              ),
                            ]),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            _LivePreview(
              sku: _sku.text.trim(),
              name: _name.text.trim(),
              category: _category,
              quantity: int.tryParse(_quantity.text.trim()),
              price: double.tryParse(_price.text.trim()),
              reorder: int.tryParse(_reorder.text.trim()),
            ),
            const SizedBox(height: 20),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _clearForm,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('saveButton'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: _saving ? null : _save,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: _saving
                        ? const SizedBox(
                            key: ValueKey('spin'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.cloud_upload_outlined,
                            key: ValueKey('icon')),
                  ),
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(_saving ? 'Saving to Firestore…' : 'Save Item',
                        key: ValueKey(_saving)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Animated "x of 6 fields valid" bar at the top of the form.
class _ProgressMeter extends StatelessWidget {
  final int done;
  final int total;

  const _ProgressMeter({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = done == total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(complete),
            size: 18,
            color: complete
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        const SizedBox(width: 6),
        Text(complete ? 'Ready to save' : '$done of $total fields valid',
            style: theme.textTheme.labelMedium),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: done / total),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    ]);
  }
}

/// Shows what the inventory card will look like while the user types.
class _LivePreview extends StatelessWidget {
  final String sku;
  final String name;
  final String? category;
  final int? quantity;
  final double? price;
  final int? reorder;

  const _LivePreview({
    required this.sku,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.reorder,
  });

  bool get _isEmpty =>
      sku.isEmpty &&
      name.isEmpty &&
      category == null &&
      quantity == null &&
      price == null &&
      reorder == null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final low = quantity != null && reorder != null && quantity! <= reorder!;
    final accent = category == null
        ? scheme.outline
        : StockItemCard.colorFor(category!, scheme);
    final value = (quantity ?? 0) * (price ?? 0);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _isEmpty
          ? const SizedBox(width: double.infinity)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Live preview', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: accent.withAlpha(18),
                  border: Border.all(
                      color: low
                          ? scheme.error.withAlpha(140)
                          : accent.withAlpha(90)),
                ),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(40),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (c, a) => RotationTransition(
                        turns: Tween(begin: 0.75, end: 1.0).animate(a),
                        child: FadeTransition(opacity: a, child: c),
                      ),
                      child: Icon(
                        StockItemCard.iconFor(category ?? ''),
                        key: ValueKey(category),
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'Item name' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: name.isEmpty ? scheme.outline : null,
                              )),
                          Text(
                            '${sku.isEmpty ? 'STK-___' : sku} · '
                            '${category ?? 'No category'}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Value RM ${value.toStringAsFixed(2)}'
                            '${low ? ' · will be flagged low stock' : ''}',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: low
                                    ? scheme.error
                                    : scheme.onSurfaceVariant),
                          ),
                        ]),
                  ),
                  Column(children: [
                    Text(quantity?.toString() ?? '–',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: low ? scheme.error : scheme.primary,
                        )),
                    Text('in stock', style: theme.textTheme.labelSmall),
                  ]),
                ]),
              ),
            ]),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
