import 'package:flutter/material.dart';

import '../models/stock_item.dart';
import '../services/inventory_repository.dart';
import '../utils/inventory_filter.dart';
import '../widgets/stock_item_card.dart';

/// Task 2 + Task 3: live Firestore inventory list with advanced search.
class InventoryScreen extends StatefulWidget {
  final InventoryRepository repository;

  const InventoryScreen({super.key, required this.repository});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  late Stream<List<StockItem>> _stream;
  InventoryFilter _filter = InventoryFilter.none;
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchItems();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 400;
      if (show != _showTop) setState(() => _showTop = show);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Re-subscribes to Firestore so the list is re-read from the database.
  Future<void> _reload() async {
    setState(() => _stream = widget.repository.watchItems());
    await _stream.first.catchError((_) => <StockItem>[]);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _filter = InventoryFilter.none);
  }

  void _setCategory(String? c) {
    setState(() => _filter = c == null
        ? _filter.copyWith(clearCategory: true)
        : _filter.copyWith(category: c));
  }

  void _toggleCategory(String c) =>
      _setCategory(_filter.category == c ? null : c);

  void _scrollToTop() => _scroll.animateTo(0,
      duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockItem>>(
      stream: _stream,
      builder: (context, snapshot) {
        final Widget child;
        if (snapshot.hasError) {
          child = _StateMessage(
            key: const ValueKey('error'),
            icon: Icons.cloud_off,
            title: 'Could not load inventory from Firestore',
            message: '${snapshot.error}',
            action: FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          );
        } else if (!snapshot.hasData) {
          child = const _StateMessage(
            key: ValueKey('loading'),
            icon: Icons.cloud_sync_outlined,
            title: 'Loading inventory from Firestore…',
            loading: true,
          );
        } else {
          child = KeyedSubtree(
            key: const ValueKey('data'),
            child: _buildData(snapshot.data!),
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          child: child,
        );
      },
    );
  }

  Widget _buildData(List<StockItem> all) {
    final visible = _filter.apply(all);
    // Changing the filter re-keys the list so the cards animate in again.
    final listKey = '${_filter.keyword}|${_filter.category}|'
        '${_filter.lowStockOnly}|${_filter.sort}';

    return Stack(children: [
      RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              sliver: SliverToBoxAdapter(child: _SummaryRow(items: all)),
            ),
            if (all.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _CategoryBreakdown(
                    items: all,
                    selected: _filter.category,
                    onTap: _toggleCategory,
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver:
                  SliverToBoxAdapter(child: _buildSearchControls(all, visible)),
            ),
            if (all.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _StateMessage(
                  icon: Icons.inventory_2_outlined,
                  title: 'No stock items yet',
                  message: 'Add your first item using the form. It will '
                      'appear here as soon as Firestore saves it.',
                ),
              )
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _StateMessage(
                  key: const Key('noResults'),
                  icon: Icons.search_off,
                  title: 'No items match your filters',
                  message: _describeFilters(),
                  action: OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Clear Filters'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                sliver: SliverList.separated(
                  key: ValueKey(listKey),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _EntryAnimation(
                    key: ValueKey('anim_${visible[i].id ?? visible[i].sku}'),
                    index: i,
                    child: StockItemCard(
                      item: visible[i],
                      onFilterCategory: _setCategory,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: AnimatedScale(
          scale: _showTop ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          curve: _showTop ? Curves.easeOutBack : Curves.easeIn,
          child: FloatingActionButton.small(
            heroTag: null,
            tooltip: 'Back to top',
            onPressed: _scrollToTop,
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSearchControls(List<StockItem> all, List<StockItem> visible) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        TextField(
          key: const Key('searchField'),
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by item name or SKU (e.g. mouse, stk-102)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: _filter.keyword.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filter = _filter.copyWith(keyword: ''));
                      },
                    ),
            ),
          ),
          onChanged: (v) =>
              setState(() => _filter = _filter.copyWith(keyword: v)),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final c in <String?>[null, ...StockItem.categories])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('category_${c ?? 'All'}'),
                  avatar: c == null
                      ? null
                      : Icon(StockItemCard.iconFor(c), size: 18),
                  label: Text(c == null
                      ? 'All'
                      : '$c (${all.where((i) => i.category == c).length})'),
                  selected: _filter.category == c,
                  onSelected: (_) => _setCategory(c),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              key: const Key('lowStockChip'),
              avatar: Icon(Icons.warning_amber_rounded,
                  size: 18, color: theme.colorScheme.error),
              label: const Text('Low stock only'),
              selected: _filter.lowStockOnly,
              onSelected: (v) =>
                  setState(() => _filter = _filter.copyWith(lowStockOnly: v)),
            ),
            SegmentedButton<QuantitySort>(
              key: const Key('sortControl'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: QuantitySort.newest,
                    icon: Icon(Icons.schedule, size: 18),
                    label: Text('Newest')),
                ButtonSegment(
                    value: QuantitySort.ascending,
                    icon: Icon(Icons.arrow_upward, size: 18),
                    label: Text('Qty asc')),
                ButtonSegment(
                    value: QuantitySort.descending,
                    icon: Icon(Icons.arrow_downward, size: 18),
                    label: Text('Qty desc')),
              ],
              selected: {_filter.sort},
              onSelectionChanged: (s) =>
                  setState(() => _filter = _filter.copyWith(sort: s.first)),
            ),
            AnimatedOpacity(
              opacity: _filter.isDefault ? 0.5 : 1,
              duration: const Duration(milliseconds: 200),
              child: TextButton.icon(
                key: const Key('clearFilters'),
                onPressed: _filter.isDefault ? null : _clearFilters,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Clear Filters'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Showing ${visible.length} of ${all.length} items from Firestore'
          '${_filter.sort == QuantitySort.ascending ? ' · quantity low → high' : ''}'
          '${_filter.sort == QuantitySort.descending ? ' · quantity high → low' : ''}',
          key: const Key('resultCount'),
          style: theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  String _describeFilters() {
    final parts = <String>[
      if (_filter.keyword.trim().isNotEmpty)
        'keyword "${_filter.keyword.trim()}"',
      if (_filter.category != null) 'category ${_filter.category}',
      if (_filter.lowStockOnly) 'low stock only',
    ];
    return 'Nothing in Firestore matches ${parts.join(' + ')}. '
        'Try a different keyword or clear the filters.';
  }
}

/// Fades and slides a list card in, staggered by its position.
class _EntryAnimation extends StatelessWidget {
  final int index;
  final Widget child;

  const _EntryAnimation({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 8)) * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Interval(delay / (320 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<StockItem> items;

  const _SummaryRow({required this.items});

  @override
  Widget build(BuildContext context) {
    final low = items.where((i) => i.isLowStock).length;
    final value = items.fold<double>(0, (sum, i) => sum + i.stockValue);
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      _Stat(
        label: 'Items',
        value: items.length.toDouble(),
        format: (v) => '${v.round()}',
        icon: Icons.inventory_2_outlined,
      ),
      const SizedBox(width: 10),
      _Stat(
        label: 'Low stock',
        value: low.toDouble(),
        format: (v) => '${v.round()}',
        icon: Icons.warning_amber_rounded,
        color: low > 0 ? scheme.error : null,
      ),
      const SizedBox(width: 10),
      _Stat(
        label: 'Stock value',
        value: value,
        format: (v) => 'RM ${v.toStringAsFixed(2)}',
        icon: Icons.payments_outlined,
      ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final double value;
  final String Function(double) format;
  final IconData icon;
  final Color? color;

  const _Stat({
    required this.label,
    required this.value,
    required this.format,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withAlpha(36),
              theme.colorScheme.surfaceContainerHigh,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(format(v),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: color)),
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ]),
      ),
    );
  }
}

/// Stacked bar of stock value per category. Tapping a segment or legend
/// entry filters the list to that category.
class _CategoryBreakdown extends StatelessWidget {
  final List<StockItem> items;
  final String? selected;
  final ValueChanged<String> onTap;

  const _CategoryBreakdown({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final counts = {
      for (final c in StockItem.categories)
        c: items.where((i) => i.category == c).length,
    };
    final present = StockItem.categories.where((c) => counts[c]! > 0).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Items by category', style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(children: [
              for (final c in present)
                Expanded(
                  flex: counts[c]!,
                  child: Tooltip(
                    message: '$c: ${counts[c]} items',
                    child: GestureDetector(
                      onTap: () => onTap(c),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 2),
                          color: StockItemCard.colorFor(c, scheme).withAlpha(
                              selected == null || selected == c ? 255 : 70),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final c in present)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onTap(c),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: selected == null || selected == c ? 1 : 0.45,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: StockItemCard.colorFor(c, scheme),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$c · ${counts[c]}', style: theme.textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool loading;

  const _StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.9, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (_, s, c) => Transform.scale(scale: s, child: c),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            loading
                ? const CircularProgressIndicator()
                : Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(icon, size: 44, color: theme.colorScheme.outline),
                  ),
            const SizedBox(height: 16),
            Text(title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      ),
    );
  }
}
