import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../data/db/app_database.dart';
import '../state/products_provider.dart';
import 'product_form_screen.dart';
import 'stock_adjustment_screen.dart';
import 'categories_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Products'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber, size: 16),
                  SizedBox(width: 4),
                  Text('Low Stock'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          _buildCategoryFilter(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllProductsTab(searchQuery: _searchQuery, categoryId: _selectedCategoryId),
                _LowStockTab(searchQuery: _searchQuery, categoryId: _selectedCategoryId),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categoriesAsync = ref.watch(categoriesProvider);
    return categoriesAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        return Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('All'),
                  selected: _selectedCategoryId == null,
                  onSelected: (v) => setState(() => _selectedCategoryId = null),
                ),
              ),
              ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(cat.name),
                  selected: _selectedCategoryId == cat.id,
                  onSelected: (v) => setState(() => _selectedCategoryId = cat.id),
                ),
              )),
            ],
          ),
        );
      },
    );
  }
}

class _AllProductsTab extends ConsumerWidget {
  final String searchQuery;
  final String? categoryId;
  const _AllProductsTab({required this.searchQuery, this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = searchQuery.isEmpty
        ? ref.watch(productsProvider)
        : ref.watch(productSearchProvider(searchQuery));

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        final filtered = categoryId == null
            ? products
            : products.where((p) => p.categoryId == categoryId).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  searchQuery.isNotEmpty ? 'No results for "$searchQuery"' : 'No products yet',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }
        return _ProductList(products: filtered);
      },
    );
  }
}

class _LowStockTab extends ConsumerWidget {
  final String searchQuery;
  final String? categoryId;
  const _LowStockTab({required this.searchQuery, this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(lowStockProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) {
        final filtered = searchQuery.isEmpty
            ? products
            : products
                .where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
        final categoryFiltered = categoryId == null
            ? filtered
            : filtered.where((p) => p.categoryId == categoryId).toList();

        if (categoryFiltered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 12),
                Text('All stock levels look good!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return _ProductList(products: categoryFiltered, highlightLowStock: true);
      },
    );
  }
}

class _ProductList extends ConsumerWidget {
  final List<Product> products;
  final bool highlightLowStock;
  const _ProductList({required this.products, this.highlightLowStock = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final isOut = p.stockQty == 0;
        final isLow = p.stockQty <= p.lowStockThreshold;

        Color stockColor = Colors.green;
        if (isOut) stockColor = Colors.red;
        else if (isLow) stockColor = Colors.orange;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: SizedBox(
              width: 52,
              height: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: p.imagePath != null
                    ? Image.file(File(p.imagePath!), fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.inventory_2, color: Colors.grey[400], size: 28),
                      ),
              ),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(p.priceCents) +
                      (p.costCents != null ? ' · Cost: ${formatCurrency(p.costCents!)}' : ''),
                  style: const TextStyle(fontSize: 12),
                ),
                if (p.barcode != null)
                  Text('SKU: ${p.barcode}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            isThreeLine: p.barcode != null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: stockColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    isOut ? 'Out of stock' : '${p.stockQty} ${p.unit}',
                    style: TextStyle(
                        color: stockColor, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => StockAdjustmentScreen(product: p)),
                  ),
                  child: const Text('Adjust stock',
                      style: TextStyle(
                          fontSize: 11, color: Colors.blue,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ProductFormScreen(product: p)),
            ),
          ),
        );
      },
    );
  }
}