import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showFloatingButtons = shouldShow;
            if (shouldShow) _isSearchExpanded = false;
          });
        }
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
              if (!_showFloatingButtons)
                Container(
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
                              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                            _buildFloatingCategoryButton(),
                          ],
                        ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        tooltip: 'Add Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryButton() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final hasActiveFilter = _selectedCategoryId != null || _tabController.index == 1;
    return categoriesAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: hasActiveFilter ? const Color(0xFF2D5F3F) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: hasActiveFilter ? const Color(0xFF2D5F3F) : Colors.grey.shade300),
          ),
          child: IconButton(
            icon: Icon(
              Icons.filter_list,
              color: hasActiveFilter ? Colors.white : const Color(0xFF1A1A1A),
            ),
            tooltip: 'Filters',
            onPressed: () => _showCategoryPicker(categories),
          ),
        );
      },
    );
  }

  Widget _buildFloatingCategoryButton() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final hasActiveFilter = _selectedCategoryId != null || _tabController.index == 1;
    return categoriesAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox();
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(24),
          color: hasActiveFilter ? const Color(0xFF2D5F3F) : Colors.white,
          child: InkWell(
            onTap: () => _showCategoryPicker(categories),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                Icons.filter_list,
                color: hasActiveFilter ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    int tempTabIndex = _tabController.index;
    String? tempCategoryId = _selectedCategoryId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Column(
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
                  const Text('Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text('Stock Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tempTabIndex == 0 ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        color: tempTabIndex == 0 ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
                      ),
                    ),
                    title: const Text('All Products', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Show all inventory items', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    selected: tempTabIndex == 0,
                    selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      setModalState(() => tempTabIndex = 0);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tempTabIndex == 1 ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: tempTabIndex == 1 ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
                      ),
                    ),
                    title: const Text('Low Stock', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Items below threshold', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    selected: tempTabIndex == 1,
                    selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      setModalState(() => tempTabIndex = 1);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text('Category Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tempCategoryId == null ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        color: tempCategoryId == null ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
                      ),
                    ),
                    title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w500)),
                    selected: tempCategoryId == null,
                    selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      setModalState(() => tempCategoryId = null);
                    },
                  ),
                  ...categories.map((cat) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tempCategoryId == cat.id ? const Color(0xFF2D5F3F).withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        color: tempCategoryId == cat.id ? const Color(0xFF2D5F3F) : const Color(0xFF6B7280),
                      ),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    selected: tempCategoryId == cat.id,
                    selectedTileColor: const Color(0xFF2D5F3F).withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      setModalState(() => tempCategoryId = cat.id);
                    },
                  )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _tabController.index = tempTabIndex;
                      _selectedCategoryId = tempCategoryId;
                      _showFloatingButtons = false;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ),
          ],
        ),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Slidable(
            key: ValueKey(p.id),
            startActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.3,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF2D5F3F),
                        ),
                        child: const Center(
                          child: Text(
                            'Edit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
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
                    onTap: () {},
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
                                    Icon(_getUnitIcon(p.unit), size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOut ? 'Out of stock' : '${p.stockQty} ${p.unit}',
                                      style: TextStyle(
                                        color: isOut ? Colors.red.shade700 : Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (p.barcode != null)
                                      const SizedBox(width: 12),
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
              ),
            ),
          ),
        );
      },
    );
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
}
