import 'package:flutter/material.dart';
import 'package:tindako/features/pos/ui/pos_screen.dart';
import 'package:tindako/features/products/ui/products_screen.dart';
import 'package:tindako/features/invoices/ui/invoice_history_screen.dart';
import 'package:tindako/features/utang/ui/utang_screen.dart';
import 'package:tindako/features/reports/ui/reports_screen.dart';
import 'package:tindako/core/widgets/lazy_page_wrapper.dart';
import 'package:tindako/core/widgets/skeleton_screens.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  late PageController _pageController;
  final Set<int> _preloadedPages = {0}; // Preload POS screen

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeScreens();
  }

  void _initializeScreens() {
    _screens = [
      LazyPageWrapper(
        builder: () => const PosScreen(),
        skeleton: const PosSkeletonScreen(),
        preload: true,
      ),
      LazyPageWrapper(
        builder: () => const ProductsScreen(),
        skeleton: const ProductsSkeletonScreen(),
      ),
      LazyPageWrapper(
        builder: () => const InvoiceHistoryScreen(),
        skeleton: const InvoicesSkeletonScreen(),
      ),
      LazyPageWrapper(
        builder: () => const UtangScreen(),
        skeleton: const UtangSkeletonScreen(),
      ),
      LazyPageWrapper(
        builder: () => const ReportsScreen(),
        skeleton: const ReportsSkeletonScreen(),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (!didPop && _selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          _pageController.jumpToPage(0);
        }
      },
      child: Scaffold(
        body: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() => _selectedIndex = index);
            _preloadAdjacentPages(index);
          },
          physics: const BouncingScrollPhysics(),
          itemCount: _screens.length,
          itemBuilder: (context, index) => _screens[index],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) {
              setState(() => _selectedIndex = i);
              _pageController.jumpToPage(i);
              _preloadAdjacentPages(i);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: const Color(0xFF2D5F3F).withOpacity(0.1),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.point_of_sale_outlined),
                selectedIcon: Icon(Icons.point_of_sale),
                label: 'Sell',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Products',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Invoices',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: 'Utang',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Reports',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _preloadAdjacentPages(int currentIndex) {
    // Preload adjacent pages for smoother transitions
    final pagesToPreload = <int>{};
    
    if (currentIndex > 0) pagesToPreload.add(currentIndex - 1);
    if (currentIndex < _screens.length - 1) pagesToPreload.add(currentIndex + 1);
    
    for (final pageIndex in pagesToPreload) {
      if (!_preloadedPages.contains(pageIndex)) {
        _preloadedPages.add(pageIndex);
        // Trigger preload by accessing the page
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            // This will trigger the LazyPageWrapper to start loading
            final page = _screens[pageIndex];
            if (page is LazyPageWrapper) {
              // The page will automatically start loading when accessed
            }
          }
        });
      }
    }
  }
}