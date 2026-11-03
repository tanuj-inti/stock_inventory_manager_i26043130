import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_inventory_manager/app.dart';

import 'fake_inventory_repository.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, FakeInventoryRepository repo,
      {Size size = const Size(1280, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(StockInventoryApp(repository: repo));
    await tester.pumpAndSettle();
  }

  testWidgets('Invalid submission shows inline errors and writes nothing',
      (tester) async {
    final repo = FakeInventoryRepository();
    await pumpApp(tester, repo);

    await tester.enterText(find.byKey(const Key('skuField')), 'STK-1');
    await tester.enterText(find.byKey(const Key('nameField')), 'ab');
    await tester.enterText(find.byKey(const Key('quantityField')), '-2');
    await tester.enterText(find.byKey(const Key('priceField')), '0');
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('STK- followed by three digits, e.g.'), findsOneWidget);
    expect(find.text('Item name must be at least 3 characters'), findsOneWidget);
    expect(find.text('Please select a category'), findsOneWidget);
    expect(find.text('Quantity cannot be negative'), findsOneWidget);
    expect(find.text('Reorder level is required'), findsOneWidget);
    expect(find.text('Unit price must be greater than RM 0'), findsOneWidget);
    expect(repo.writes, isEmpty);
  });

  testWidgets('Valid save writes typed fields and appears in the list',
      (tester) async {
    final repo = FakeInventoryRepository();
    await pumpApp(tester, repo);

    await tester.tap(find.text('Fill STK-101'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(repo.writes, hasLength(1));
    final w = repo.writes.single;
    expect(w['sku'], 'STK-101');
    expect(w['quantity'], isA<int>());
    expect(w['unitPrice'], 19.90);
    expect(w['reorderLevel'], isA<int>());
    expect(find.byKey(const Key('item_STK-101')), findsOneWidget);
    expect(find.textContaining('Saved STK-101'), findsOneWidget);
  });

  testWidgets('Failed write keeps form input and shows an error', (tester) async {
    final repo = FakeInventoryRepository()..failWrites = true;
    await pumpApp(tester, repo);

    await tester.tap(find.text('Fill STK-102'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saveError')), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'STK-102'), findsOneWidget);
  });

  testWidgets('Combined search, no-results and Clear Filters', (tester) async {
    final repo = FakeInventoryRepository(acceptanceItems);
    await pumpApp(tester, repo);

    await tester.enterText(find.byKey(const Key('searchField')), 'mouse');
    await tester.tap(find.byKey(const Key('category_Electronics')));
    await tester.tap(find.byKey(const Key('lowStockChip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('item_STK-103')), findsOneWidget);
    expect(find.byKey(const Key('item_STK-101')), findsNothing);
    expect(find.byKey(const Key('item_STK-102')), findsNothing);

    await tester.enterText(find.byKey(const Key('searchField')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noResults')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearFilters')));
    await tester.pumpAndSettle();
    for (final sku in ['STK-101', 'STK-102', 'STK-103']) {
      expect(find.byKey(Key('item_$sku')), findsOneWidget);
    }
  });
}
