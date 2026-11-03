import 'package:flutter/material.dart';

import 'models/stock_item.dart';
import 'screens/add_item_screen.dart';
import 'screens/inventory_screen.dart';
import 'services/inventory_repository.dart';

/// Student details shown in the app bar and About dialog.
class StudentInfo {
  static const String name = 'Tanuj Sakthi Kumar';
  static const String university = 'SIST';
  static const String course = 'NET4207 Cross Platform Mobile App Development';
}

class StockInventoryApp extends StatelessWidget {
  final InventoryRepository repository;

  const StockInventoryApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E); // teal
    return MaterialApp(
      title: 'Stock Inventory Manager',
      debugShowCheckedModeBanner: false,
      theme: _theme(ColorScheme.fromSeed(seedColor: seed)),
      darkTheme: _theme(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      home: HomeShell(repository: repository),
    );
  }

  ThemeData _theme(ColorScheme scheme) {
    final radius = BorderRadius.circular(14);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: scheme.surfaceTint,
        scrolledUnderElevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    );
  }
}

/// Two-tab shell on phones; side-by-side form and inventory on wide screens.
class HomeShell extends StatefulWidget {
  final InventoryRepository repository;

  const HomeShell({super.key, required this.repository});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final Stream<List<StockItem>> _badgeStream =
      widget.repository.watchItems();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i == _tab) return;
    setState(() => _tab = i);
    _fade.forward(from: 0);
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'Stock Inventory Manager',
      applicationVersion: '1.1.0',
      applicationIcon: const Icon(Icons.inventory_2_rounded, size: 40),
      children: const [
        Text('Student: ${StudentInfo.name}'),
        Text('University: ${StudentInfo.university}'),
        Text(StudentInfo.course),
        SizedBox(height: 8),
        Text('Flutter + Firebase Cloud Firestore (collection: stockItems)'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final addScreen = AddItemScreen(
      repository: widget.repository,
      onSaved: () {
        // On phones jump to the inventory so the saved record is visible.
        if (MediaQuery.sizeOf(context).width < 900) _goTo(1);
      },
    );
    final inventoryScreen = InventoryScreen(repository: widget.repository);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.tertiary
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(70),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.inventory_2_rounded,
                  color: theme.colorScheme.onPrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stock Inventory Manager',
                      overflow: TextOverflow.ellipsis),
                  Text(
                    '${StudentInfo.name} · ${StudentInfo.university}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ]),
          actions: [
            IconButton(
              tooltip: 'About',
              icon: const Icon(Icons.info_outline),
              onPressed: _showAbout,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 440, child: addScreen),
                const VerticalDivider(width: 1),
                Expanded(child: inventoryScreen),
              ])
            : FadeTransition(
                opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: _fade, curve: Curves.easeOutCubic)),
                  child: IndexedStack(
                    index: _tab,
                    children: [addScreen, inventoryScreen],
                  ),
                ),
              ),
        bottomNavigationBar: wide
            ? null
            : StreamBuilder<List<StockItem>>(
                stream: _badgeStream,
                builder: (context, snap) {
                  final low = snap.data?.where((i) => i.isLowStock).length ?? 0;
                  return NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: _goTo,
                    animationDuration: const Duration(milliseconds: 400),
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(Icons.add_box_outlined),
                        selectedIcon: Icon(Icons.add_box),
                        label: 'Add item',
                      ),
                      NavigationDestination(
                        icon: Badge(
                          isLabelVisible: low > 0,
                          label: Text('$low'),
                          child: const Icon(Icons.inventory_2_outlined),
                        ),
                        selectedIcon: Badge(
                          isLabelVisible: low > 0,
                          label: Text('$low'),
                          child: const Icon(Icons.inventory_2),
                        ),
                        label: 'Inventory',
                        tooltip: low > 0 ? '$low items low on stock' : null,
                      ),
                    ],
                  );
                },
              ),
      );
    });
  }
}
