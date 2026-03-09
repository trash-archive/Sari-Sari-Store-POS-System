import 'package:flutter/material.dart';
import 'package:tindako/features/pos/ui/pos_screen.dart';
import 'package:tindako/features/products/ui/products_screen.dart';
import 'package:tindako/features/invoices/ui/invoice_history_screen.dart';
import 'package:tindako/features/utang/ui/utang_screen.dart';
import 'package:tindako/features/reports/ui/reports_screen.dart';
import 'package:tindako/features/settings/ui/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  late PageController _pageController;

  final List<Widget> _screens = const [
    PosScreen(),
    ProductsScreen(),
    InvoiceHistoryScreen(),
    UtangScreen(),
    ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          physics: const PageScrollPhysics(),
          children: _screens,
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
}