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
  final _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _showFloatingButtons = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && !_showFloatingButtons) {
      setState(() => _showFloatingButtons = true);
    } else if (_scrollController.offset <= 50 && _showFloatingButtons) {
      setState(() => _showFloatingButtons = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.w600)),
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
            Tab(text: 'Low Stock'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _showFloatingButtons ? 0 : 72,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showFloatingButtons ? 0 : 1,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: TextStyle(color: Color(0xFF6B7280)),
                                prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(top: 14, bottom: 14),
                                filled: false,
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildCategoryButton(),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _AllProductsTab(searchQuery: _searchQuery, categoryId: _selectedCategoryId, scrollController: _scrollController),
                    _LowStockTab(searchQuery: _searchQuery, categoryId: _selectedCategoryId, scrollController: _scrollController),
                  ],
                ),
              ),
            ],
          ),
          if (_showFloatingButtons)
            Positioned(
              top: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showFloatingButtons ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white,
                      child: InkWell(
                        onTap: () => _showSearchDialog(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          child: const Icon(Icons.search, color: Color(0xFF1A1A1A)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingCategoryButton(),
                  ],
                ),
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

  Widget _buildCategoryButton() {
    final categoriesAsync = ref.watch(categoriesProvider);
    return categoriesAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        return Container(
          decoration: BoxDecoration(
            color: _selectedCategoryId != null ? const Color(0xFF2D5F3F) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _selectedCategoryId != null ? const Color(0xFF2D5F3F) : Colors.grey.shade300),
          ),
          child: IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _selectedCategoryId != null ? Colors.white : const Color(0xFF1A1A1A),
            ),
            tooltip: 'Filter by category',
            onPressed: () => _showCategoryPicker(categories),
          ),
        );
      },
    );
  }

  Widget _buildFloatingCategoryButton() {
    final categoriesAsync = ref.watch(categoriesProvider);
    return categoriesAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(24),
          color: _selectedCategoryId != null ? const Color(0xFF2D5F3F) : Colors.white,
          child: InkWell(
            onTap: () => _showCategoryPicker(categories),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                Icons.filter_list,
                color: _selectedCategoryId != null ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('Filter by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedCategoryId == null ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: _selectedCategoryId == null ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
                    ),
                  ),
                  title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w500)),
                  selected: _selectedCategoryId == null,
                  selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    setState(() => _selectedCategoryId = null);
                    Navigator.pop(ctx);
                  },
                ),
                ...categories.map((cat) => ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedCategoryId == cat.id ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.category_outlined,
                      color: _selectedCategoryId == cat.id ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
                    ),
                  ),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  selected: _selectedCategoryId == cat.id,
                  selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    setState(() => _selectedCategoryId = cat.id);
                    Navigator.pop(ctx);
                  },
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AllProductsTab extends ConsumerWidget {
  final String searchQuery;
  final String? categoryId;
  final ScrollController scrollController;
  const _AllProductsTab({required this.searchQuery, this.categoryId, required this.scrollController});

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
        return _ProductList(products: filtered, scrollController: scrollController);
      },
    );
  }
}

class _LowStockTab extends ConsumerWidget {
  final String searchQuery;
  final String? categoryId;
  final ScrollController scrollController;
  const _LowStockTab({required this.searchQuery, this.categoryId, required this.scrollController});

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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 12),
                Text('All stock levels look good!',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }
        return _ProductList(products: categoryFiltered, highlightLowStock: true, scrollController: scrollController);
      },
    );
  }
}

class _ProductList extends ConsumerWidget {
  final List<Product> products;
  final bool highlightLowStock;
  final ScrollController scrollController;
  const _ProductList({required this.products, this.highlightLowStock = false, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        final isOut = p.stockQty == 0;
        final isLow = p.stockQty <= p.lowStockThreshold;

        Color stockColor = Colors.green;
        if (isOut) stockColor = Colors.red;
        else if (isLow) stockColor = Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProductFormScreen(product: p)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: p.imagePath != null
                            ? Image.file(File(p.imagePath!), fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFFF8F9FA),
                                child: Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 32),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1A1A1A)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => StockAdjustmentScreen(product: p)),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D5F3F).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Adjust',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF2D5F3F), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                formatCurrency(p.priceCents),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D5F3F)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: stockColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: stockColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  isOut ? 'Out of stock' : 'Stock: ${p.stockQty}',
                                  style: TextStyle(
                                      color: stockColor, fontWeight: FontWeight.w600, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          if (p.barcode != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'SKU: ${p.barcode}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}