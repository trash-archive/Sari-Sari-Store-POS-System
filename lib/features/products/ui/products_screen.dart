import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/utils/currency.dart';
import '../../../data/db/app_database.dart';
import '../../settings/ui/settings_screen.dart';
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
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShow = offset > 50;
    
    if (shouldShow != _showFloatingButtons) {
      setState(() {
        _showFloatingButtons = shouldShow;
        if (shouldShow) _isSearchExpanded = false;
      });
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: TextStyle(color: Color(0xFF6B7280)),
                                prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                                filled: false,
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildStockFilterDropdown(),
                        const SizedBox(width: 12),
                        _buildCategoryButton(),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _tabController.index == 0
                    ? _AllProductsTab(searchQuery: _searchQuery, categoryId: _selectedCategoryId, scrollController: _scrollController)
                    : _LowStockTab(searchQuery: _searchQuery, categoryId: _selectedCategoryId, scrollController: _scrollController),
              ),
            ],
          ),
          if (_showFloatingButtons)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: IgnorePointer(
                ignoring: !_showFloatingButtons,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showFloatingButtons ? 1 : 0,
                  child: _isSearchExpanded
                      ? Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.grey.shade300),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(left: 12),
                                      child: Icon(Icons.search, color: Color(0xFF6B7280)),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchCtrl,
                                        autofocus: true,
                                        decoration: const InputDecoration(
                                          hintText: 'Search products...',
                                          hintStyle: TextStyle(color: Color(0xFF6B7280)),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                        ),
                                        onChanged: (v) => setState(() => _searchQuery = v),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                                      onPressed: () {
                                        FocusScope.of(context).unfocus();
                                        setState(() {
                                          _isSearchExpanded = false;
                                          _searchQuery = '';
                                          _searchCtrl.clear();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildFloatingStockFilterDropdown(),
                            const SizedBox(width: 12),
                            _buildFloatingCategoryButton(),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(24),
                              color: Colors.white,
                              child: InkWell(
                                onTap: () => setState(() => _isSearchExpanded = true),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.search, color: Color(0xFF1A1A1A)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildFloatingStockFilterDropdown(),
                            const SizedBox(width: 12),
                            _buildFloatingCategoryButton(),
                          ],
                        ),
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

  Widget _buildStockFilterDropdown() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _tabController.index == 1 ? const Color(0xFF2D5F3F) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _tabController.index == 1 ? const Color(0xFF2D5F3F) : Colors.grey.shade300),
      ),
      child: Center(
        child: IconButton(
          icon: Icon(
            _tabController.index == 0 ? Icons.inventory_2 : Icons.warning_amber_rounded,
            color: _tabController.index == 1 ? Colors.white : const Color(0xFF1A1A1A),
            size: 22,
          ),
          tooltip: 'Stock filter',
          onPressed: _showStockFilterPicker,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildFloatingStockFilterDropdown() {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      color: _tabController.index == 1 ? const Color(0xFF2D5F3F) : Colors.white,
      child: InkWell(
        onTap: _showStockFilterPicker,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(
            _tabController.index == 0 ? Icons.inventory_2 : Icons.warning_amber_rounded,
            color: _tabController.index == 1 ? Colors.white : const Color(0xFF1A1A1A),
            size: 22,
          ),
        ),
      ),
    );
  }

  void _showStockFilterPicker() {
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
                const Text('Stock Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tabController.index == 0 ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                color: _tabController.index == 0 ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
              ),
            ),
            title: const Text('All Products', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Show all inventory items', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            selected: _tabController.index == 0,
            selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              setState(() => _tabController.index = 0);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tabController.index == 1 ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: _tabController.index == 1 ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
              ),
            ),
            title: const Text('Low Stock', style: TextStyle(fontWeight: FontWeight.w500)),
            subtitle: const Text('Items below threshold', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            selected: _tabController.index == 1,
            selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () {
              setState(() => _tabController.index = 1);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 8),
        ],
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _selectedCategoryId != null ? const Color(0xFF2D5F3F) : Colors.white,
            shape: BoxShape.circle,
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                const SizedBox(height: 16),
                const Text(
                  'All Stock Levels Look Good!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 8),
                Text(
                  'No products are below their stock threshold',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
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

  void _showProductOptions(BuildContext context, WidgetRef ref, Product product) {
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
            child: Column(
              children: [
                Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(formatCurrency(product.priceCents), style: const TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D5F3F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, color: Color(0xFF2D5F3F)),
            ),
            title: const Text('Edit Product'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)));
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            title: const Text('Delete Product', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context, ref, product);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(databaseProvider).productsDao.softDeleteProduct(product.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${product.name} deleted'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

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
              onLongPress: () => _showProductOptions(context, ref, p),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: p.imagePath != null
                            ? Image.file(File(p.imagePath!), fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFFF8F9FA),
                                child: Icon(Icons.inventory_2_outlined, color: Colors.grey[400], size: 36),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1A1A1A)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatCurrency(p.priceCents),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D5F3F)),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stockColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: stockColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_getUnitIcon(p.unit), size: 12, color: stockColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOut ? 'Out of stock' : '${p.stockQty} ${p.unit}',
                                      style: TextStyle(color: stockColor, fontWeight: FontWeight.w600, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.barcode != null)
                                const SizedBox(width: 8),
                              if (p.barcode != null)
                                Flexible(
                                  child: Text(
                                    'SKU: ${p.barcode}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.tune, color: Color(0xFF2D5F3F), size: 22),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StockAdjustmentScreen(product: p)),
                      ),
                      tooltip: 'Adjust Stock',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5F3F).withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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


  IconData _getUnitIcon(String unit) {
    switch (unit.toLowerCase()) {
      case 'pc':
      case 'pack':
        return Icons.inventory_2;
      case 'box':
        return Icons.inventory;
      case 'bottle':
        return Icons.local_drink;
      case 'can':
        return Icons.coffee;
      case 'kg':
      case 'g':
        return Icons.scale;
      case 'l':
      case 'ml':
        return Icons.water_drop;
      default:
        return Icons.inventory_2;
    }
  }
