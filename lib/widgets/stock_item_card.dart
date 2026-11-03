import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stock_item.dart';

/// One readable inventory row: SKU, name, category, quantity, price and
/// reorder level, with a clear low-stock badge. Hover lifts the card, tap
/// opens a details sheet.
class StockItemCard extends StatefulWidget {
  final StockItem item;

  /// Called when the user asks to see more items in this category from the
  /// details sheet.
  final ValueChanged<String>? onFilterCategory;

  const StockItemCard({super.key, required this.item, this.onFilterCategory});

  static IconData iconFor(String category) => switch (category) {
        'Electronics' => Icons.memory,
        'Stationery' => Icons.edit_note,
        'Hardware' => Icons.handyman_outlined,
        'Grocery' => Icons.local_grocery_store_outlined,
        _ => Icons.inventory_2_outlined,
      };

  /// A distinct accent per category, derived from the theme so it works in
  /// light and dark mode.
  static Color colorFor(String category, ColorScheme scheme) =>
      switch (category) {
        'Electronics' => scheme.primary,
        'Stationery' => scheme.tertiary,
        'Hardware' => scheme.secondary,
        'Grocery' => Color.lerp(scheme.primary, Colors.orange, 0.65)!,
        _ => scheme.outline,
      };

  /// 0..1 fill for the stock bar. Twice the reorder level counts as "full".
  static double stockRatio(StockItem item) {
    final full = (item.reorderLevel * 2).clamp(1, 1 << 30);
    return (item.quantity / full).clamp(0.0, 1.0);
  }

  @override
  State<StockItemCard> createState() => _StockItemCardState();
}

class _StockItemCardState extends State<StockItemCard> {
  bool _hover = false;
  bool _pressed = false;

  void _openDetails() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StockItemDetails(
        item: widget.item,
        onFilterCategory: widget.onFilterCategory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final low = item.isLowStock;
    final accent = StockItemCard.colorFor(item.category, scheme);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          key: Key('item_${item.sku}'),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: _hover ? scheme.surfaceContainerLow : scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: low
                  ? scheme.error.withAlpha(_hover ? 180 : 110)
                  : (_hover ? accent.withAlpha(140) : scheme.outlineVariant),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withAlpha(_hover ? 28 : 0),
                blurRadius: _hover ? 18 : 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _openDetails,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(_hover ? 60 : 36),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(StockItemCard.iconFor(item.category),
                          color: accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('${item.sku} · ${item.category}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              _Pill(
                                  text:
                                      'RM ${item.unitPrice.toStringAsFixed(2)}'),
                              _Pill(text: 'Reorder at ${item.reorderLevel}'),
                              if (low)
                                _Pill(
                                  text: 'Low stock',
                                  icon: Icons.warning_amber_rounded,
                                  background: scheme.errorContainer,
                                  foreground: scheme.onErrorContainer,
                                ),
                            ]),
                          ]),
                    ),
                    const SizedBox(width: 12),
                    Column(children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: item.quantity.toDouble()),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text('${v.round()}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: low ? scheme.error : scheme.primary,
                            )),
                      ),
                      Text('in stock', style: theme.textTheme.labelSmall),
                    ]),
                    AnimatedOpacity(
                      opacity: _hover ? 1 : 0.35,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.chevron_right,
                          color: scheme.onSurfaceVariant),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  StockBar(item: item),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin animated bar showing how healthy the stock level is.
class StockBar extends StatelessWidget {
  final StockItem item;
  final double height;

  const StockBar({super.key, required this.item, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = StockItemCard.stockRatio(item);
    final color = item.isLowStock
        ? scheme.error
        : (ratio < 0.75
            ? Color.lerp(scheme.primary, Colors.amber, 0.6)!
            : scheme.primary);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// Bottom sheet with the full record and a few quick actions.
class StockItemDetails extends StatelessWidget {
  final StockItem item;
  final ValueChanged<String>? onFilterCategory;

  const StockItemDetails(
      {super.key, required this.item, this.onFilterCategory});

  String _date(DateTime? d) {
    if (d == null) return 'Pending server timestamp';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = StockItemCard.colorFor(item.category, scheme);
    final low = item.isLowStock;
    final toReorder = (item.reorderLevel * 2 - item.quantity).clamp(0, 1 << 30);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withAlpha(45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(StockItemCard.iconFor(item.category),
                  color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text('${item.sku} · ${item.category}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
            ),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: low ? scheme.errorContainer : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(
                  low
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: low
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  low
                      ? 'Low stock: ${item.quantity} left, reorder level is '
                          '${item.reorderLevel}. Suggest ordering $toReorder more.'
                      : 'Stock is healthy: ${item.quantity - item.reorderLevel} '
                          'above the reorder level.',
                  style: TextStyle(
                      color: low
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          StockBar(item: item, height: 10),
          const SizedBox(height: 16),
          _DetailGrid(entries: [
            ('Quantity', '${item.quantity}', Icons.numbers),
            ('Reorder level', '${item.reorderLevel}', Icons.low_priority),
            (
              'Unit price',
              'RM ${item.unitPrice.toStringAsFixed(2)}',
              Icons.sell_outlined
            ),
            (
              'Stock value',
              'RM ${item.stockValue.toStringAsFixed(2)}',
              Icons.payments_outlined
            ),
          ]),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Created'),
            subtitle: Text(_date(item.createdAt)),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: item.sku));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied ${item.sku} to clipboard')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy SKU'),
            ),
            if (onFilterCategory != null)
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () {
                  Navigator.pop(context);
                  onFilterCategory!(item.category);
                },
                icon: const Icon(Icons.filter_list),
                label: Text('All ${item.category}'),
              ),
          ]),
        ],
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final List<(String, String, IconData)> entries;

  const _DetailGrid({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (label, value, icon) in entries)
          Container(
            width: w,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(label, style: theme.textTheme.bodySmall),
                    ]),
              ),
            ]),
          ),
      ]);
    });
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  const _Pill(
      {required this.text, this.icon, this.background, this.foreground});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4)
        ],
        Text(text,
            style: TextStyle(
                fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
