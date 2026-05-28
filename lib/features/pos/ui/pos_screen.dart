import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/utils/currency.dart';
import '../../../data/db/app_database.dart';
import '../../../data/services/image_storage_service.dart';
import '../../products/state/products_provider.dart';
import '../../products/ui/product_form_screen.dart';
import '../../settings/ui/settings_screen.dart';
import '../state/cart_provider.dart';
import '../../utang/state/customers_provider.dart';
import '../../invoices/ui/invoice_detail_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  bool _showFloatingButtons = false;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final productsAsync = _searchQuery.isEmpty
        ? ref.watch(productsProvider)
        : ref.watch(productSearchProvider(_searchQuery));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            ref.watch(settingsProvider).storeName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        actions: [
          if (cart.itemCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, size: 26),
                    onPressed: () => _showCart(context),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                              hintStyle: TextStyle(color: AppTheme.textSecondary),
                              prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
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
                child: productsAsync.when(
                  data: (products) {
                    final filtered = _selectedCategoryId == null
                        ? products
                        : products.where((p) => p.categoryId == _selectedCategoryId).toList();
                    return _ProductGrid(
                      products: filtered,
                      scrollController: _scrollController,
                      hasNoProductsAtAll: products.isEmpty,
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
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
                                    child: Icon(Icons.search, color: AppTheme.textSecondary),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      autofocus: true,
                                      decoration: const InputDecoration(
                                        hintText: 'Search products...',
                                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      ),
                                      onChanged: (v) => setState(() => _searchQuery = v),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
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
                                child: const Icon(Icons.search, color: AppTheme.textPrimary),
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
      bottomNavigationBar: cart.items.isEmpty ? null : _CartSummaryBar(
        cart: cart,
        onViewCart: () => _showCart(context),
      ),
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartSheet(),
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
            color: _selectedCategoryId != null ? AppTheme.primary : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _selectedCategoryId != null ? AppTheme.primary : Colors.grey.shade300),
          ),
          child: IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _selectedCategoryId != null ? Colors.white : AppTheme.textPrimary,
            ),
            tooltip: 'Filter by category',
            onPressed: () => _showCategoryPicker(categories),
          ),
        );
      },
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    String? tempCategoryId = _selectedCategoryId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: false,
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
                        color: tempCategoryId == null ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.grid_view_rounded,
                        color: tempCategoryId == null ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                    title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w500)),
                    selected: tempCategoryId == null,
                    selectedTileColor: AppTheme.primary.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      setModalState(() => tempCategoryId = null);
                    },
                  ),
                  ...categories.map((cat) => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tempCategoryId == cat.id ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        color: tempCategoryId == cat.id ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    selected: tempCategoryId == cat.id,
                    selectedTileColor: AppTheme.primary.withOpacity(0.05),
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
                      _selectedCategoryId = tempCategoryId;
                      _showFloatingButtons = false;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filter'),
                ),
              ),
            ),
          ],
        ),
      ),
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
          color: _selectedCategoryId != null ? AppTheme.primary : Colors.white,
          child: InkWell(
            onTap: () => _showCategoryPicker(categories),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              child: Icon(
                Icons.filter_list,
                color: _selectedCategoryId != null ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ProductGrid extends ConsumerWidget {
  final List<Product> products;
  final ScrollController scrollController;
  final bool hasNoProductsAtAll;
  const _ProductGrid({required this.products, required this.scrollController, required this.hasNoProductsAtAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            if (hasNoProductsAtAll) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductFormScreen()),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, i) => _ProductCard(product: products[i]),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = ref.watch(cartProvider.select((cart) => 
      cart.items.where((i) => i.product.id == product.id).firstOrNull
    ));
    final outOfStock = product.stockQty <= 0;
    final maxReached = inCart != null && inCart.qty >= product.stockQty;

    return Container(
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
          onTap: outOfStock || maxReached ? () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Text(outOfStock ? 'Out of stock' : 'Maximum quantity reached'),
                  ],
                ),
                backgroundColor: Color(0xFFE65100),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                duration: const Duration(seconds: 1),
              ),
            );
          } : () => ref.read(cartProvider.notifier).addItem(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: product.imageData != null
                          ? Image.memory(
                              product.imageData!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : product.imagePath != null
                              ? Image.file(
                                  File(product.imagePath!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : product.imageUrl != null
                                  ? Image.network(
                                      product.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    )
                                  : Container(
                                      color: AppTheme.surface,
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                                    ),
                    ),
                    if (outOfStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          child: const Center(
                            child: Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (inCart != null && !outOfStock)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '${inCart.qty}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 16,
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCurrency(product.priceCents),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (!outOfStock)
                        Text(
                          'Stock: ${product.stockQty} ${product.unit}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSummaryBar extends ConsumerWidget {
  final CartState cart;
  final VoidCallback onViewCart;
  const _CartSummaryBar({required this.cart, required this.onViewCart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onViewCart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatCurrency(cart.totalCents),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CartSheet extends ConsumerStatefulWidget {
  const CartSheet({super.key});
  @override
  ConsumerState<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<CartSheet> {
  final _notesCtrl = TextEditingController();
  int? _cashReceivedCents;
  int? _changeCents;
  String? _cashPayerName;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (context, scrollCtrl) => Column(
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  const Text('Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (cart.items.isNotEmpty)
                    TextButton(
                      onPressed: () { ref.read(cartProvider.notifier).clear(); Navigator.pop(context); },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                      child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 14)),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: cart.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('Your cart is empty', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: cart.items.length,
                        itemBuilder: (context, i) => _CartItemTile(item: cart.items[i]),
                      ),
                    ),
            ),
            if (cart.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                          ),
                        ),
                        Text(
                          formatCurrency(cart.totalCents),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _checkout(context, 'cash'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cash Payment', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _checkout(context, 'utang'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Utang', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, String type) async {
    String? customerId;
    String? photoPath;
    final enablePhotos = ref.read(settingsProvider).enableTransactionPhotos;

    if (type == 'utang') {
      customerId = await _selectOrCreateCustomer(context);
      if (customerId == null) return;
    } else if (type == 'cash') {
      final result = await _showCashPaymentDialog(context);
      if (result == null || result == false) return;
      // Get customerId from partial payment if applicable
      if (result is Map && result['customerId'] != null) {
        customerId = result['customerId'];
      }
    }

    if (enablePhotos) {
      photoPath = await _showPhotoOption(context);
    }

    final invoice = await ref.read(cartProvider.notifier).checkout(
      type: type,
      customerId: customerId,
      notes: _cashPayerName ?? (_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
      cashReceivedCents: _cashReceivedCents,
      changeCents: _changeCents,
      photoPath: photoPath,
      isPartialPayment: type == 'cash' && customerId != null,
    );

    if (!mounted) return;
    
    // Get the root context before popping
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);

    if (invoice != null) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      
      final snackbar = ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('${invoice.invoiceNo} — ${formatCurrency(invoice.totalCents)}')),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(rootContext).hideCurrentSnackBar();
              Navigator.push(
                rootContext,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                ),
              ).then((_) {
                // Ensure snackbar is hidden when returning from invoice detail
                ScaffoldMessenger.of(rootContext).hideCurrentSnackBar();
              });
            },
          ),
        ),
      );
      
      // Auto-hide snackbar after duration
      snackbar.closed.then((_) {
        if (mounted) {
          ScaffoldMessenger.of(rootContext).clearSnackBars();
        }
      });
    }
  }

  Future<String?> _showPhotoOption(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transaction Photo'),
        content: const Text('Would you like to capture a photo for this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Take Photo'),
          ),
        ],
      ),
    );

    if (result == true) {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200, maxHeight: 1200);
      if (photo != null) {
        return await ImageStorageService.saveProductImage(File(photo.path));
      }
    }
    return null;
  }

  Future<dynamic> _showCashPaymentDialog(BuildContext context) async {
    final cart = ref.read(cartProvider);
    final cashCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int changeCents = 0;
    int cashReceivedCents = 0;
    bool showNameField = false;
    bool isPartialPayment = false;
    String? selectedCustomerId;
    String? selectedCustomerName;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      const Text('Cash Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                            Text(
                              formatCurrency(cart.totalCents),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text('Cash Received', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: cashCtrl,
                          autofocus: true,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 16, right: 8),
                              child: Center(
                                widthFactor: 0,
                                child: Text('₱', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500, fontSize: 16)),
                              ),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            errorMaxLines: 2,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'Cash received is required';
                            final amount = double.tryParse(v!);
                            if (amount == null) return 'Please enter a valid amount';
                            final cents = (amount * 100).round();
                            if (cents <= 0) return 'Amount must be greater than zero';
                            return null;
                          },
                          onChanged: (v) {
                            final amount = double.tryParse(v);
                            if (amount != null) {
                              final cents = (amount * 100).round();
                              setState(() {
                                cashReceivedCents = cents;
                                if (cents >= cart.totalCents) {
                                  changeCents = cents - cart.totalCents;
                                  isPartialPayment = false;
                                } else {
                                  changeCents = 0;
                                  isPartialPayment = true;
                                }
                              });
                            } else {
                              setState(() {
                                cashReceivedCents = 0;
                                changeCents = 0;
                                isPartialPayment = false;
                              });
                            }
                          },
                        ),
                        if (changeCents > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Change', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                Text(
                                  formatCurrency(changeCents),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),
                        if (isPartialPayment)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Partial Payment',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Remaining Balance:', style: TextStyle(fontSize: 12)),
                                      Text(
                                        formatCurrency(cart.totalCents - cashReceivedCents),
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'The remaining balance will be added to customer\'s utang.',
                                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!isPartialPayment)
                          const SizedBox(height: 16),
                        if (!isPartialPayment)
                          InkWell(
                            onTap: () => setState(() => showNameField = !showNameField),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    showNameField ? Icons.check_box : Icons.check_box_outline_blank,
                                    color: showNameField ? AppTheme.primary : Colors.grey,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Add customer name (optional)', style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        if (!isPartialPayment && showNameField)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              const Text('Customer Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: nameCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Enter customer name',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  errorMaxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        if (isPartialPayment)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Text('Select Customer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                  const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (selectedCustomerId == null)
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final customers = await ref.read(databaseProvider).customersDao.searchCustomers('');
                                    if (!context.mounted) return;
                                    final result = await showDialog<Map<String, String>?>(
                                      context: context,
                                      builder: (ctx) => _CustomerPickerDialog(customers: customers),
                                    );
                                    if (result != null) {
                                      setState(() {
                                        selectedCustomerId = result['id'];
                                        selectedCustomerName = result['name'];
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Choose customer'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 48),
                                    foregroundColor: AppTheme.primary,
                                    side: const BorderSide(color: AppTheme.primary),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          selectedCustomerName!,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.close, color: Colors.green.shade700, size: 20),
                                        onPressed: () => setState(() {
                                          selectedCustomerId = null;
                                          selectedCustomerName = null;
                                        }),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: (isPartialPayment && selectedCustomerId == null) ? null : () {
                                  if (!formKey.currentState!.validate()) return;
                                  Navigator.pop(ctx, {
                                    'cash': cashReceivedCents,
                                    'change': changeCents,
                                    'name': nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                                    'isPartial': isPartialPayment,
                                    'customerId': selectedCustomerId,
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Confirm'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      _cashReceivedCents = result['cash'];
      _changeCents = result['change'];
      _cashPayerName = result['name'];
      
      if (result['isPartial'] == true) {
        // For partial payments, we don't update customer balance here
        // The checkout method will handle it properly
        return result;
      }
      
      return true;
    }
    return false;
  }

  Future<String?> _selectOrCreateCustomer(BuildContext context) async {
    final customers = await ref.read(databaseProvider).customersDao
        .searchCustomers('');

    if (!context.mounted) return null;
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => _CustomerPickerDialog(customers: customers),
    );
    return result?['id'];
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }
}

class _CartItemTile extends ConsumerWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.product.imageData != null
                  ? Image.memory(
                      item.product.imageData!,
                      fit: BoxFit.cover,
                      width: 60,
                      height: 60,
                    )
                  : item.product.imagePath != null
                      ? Image.file(
                          File(item.product.imagePath!),
                          fit: BoxFit.cover,
                          width: 60,
                          height: 60,
                        )
                      : item.product.imageUrl != null
                          ? Image.network(
                              item.product.imageUrl!,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                            )
                          : Container(
                              color: AppTheme.surface,
                              width: 60,
                              height: 60,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 24,
                                color: Colors.grey.shade400,
                              ),
                            ),
            ),
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name with ellipsis
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Quantity Controls and Total
                Row(
                  children: [
                    // Quantity Controls
                    _QuantityControls(
                      quantity: item.qty,
                      maxStock: item.product.stockQty,
                      productId: item.product.id,
                      onQuantityChanged: (newQty) {
                        notifier.updateQty(item.product.id, newQty);
                      },
                    ),
                    const Spacer(),
                    // Total Amount
                    Text(
                      formatCurrency(item.lineTotalCents),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControls extends StatefulWidget {
  final int quantity;
  final int maxStock;
  final String productId;
  final Function(int) onQuantityChanged;

  const _QuantityControls({
    required this.quantity,
    required this.maxStock,
    required this.productId,
    required this.onQuantityChanged,
  });

  @override
  State<_QuantityControls> createState() => _QuantityControlsState();
}

class _QuantityControlsState extends State<_QuantityControls> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.quantity.toString());
  }

  @override
  void didUpdateWidget(_QuantityControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quantity != oldWidget.quantity && !_isEditing) {
      _controller.text = widget.quantity.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _decreaseQuantity() {
    if (widget.quantity > 1) {
      widget.onQuantityChanged(widget.quantity - 1);
    } else {
      widget.onQuantityChanged(0); // This will remove the item
    }
  }

  void _increaseQuantity() {
    if (widget.quantity < widget.maxStock) {
      widget.onQuantityChanged(widget.quantity + 1);
    } else {
      _showStockLimitMessage();
    }
  }

  void _showStockLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('Cannot exceed available stock (${widget.maxStock})'),
          ],
        ),
        backgroundColor: Color(0xFFE65100),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onQuantitySubmitted(String value) {
    setState(() => _isEditing = false);
    
    final newQty = int.tryParse(value);
    if (newQty == null || newQty < 1) {
      // Invalid input, reset to current quantity
      _controller.text = widget.quantity.toString();
      return;
    }
    
    if (newQty > widget.maxStock) {
      // Exceeds stock, set to max stock and show message
      _controller.text = widget.maxStock.toString();
      widget.onQuantityChanged(widget.maxStock);
      _showStockLimitMessage();
    } else {
      // Valid quantity
      widget.onQuantityChanged(newQty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canIncrease = widget.quantity < widget.maxStock;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decrease button
        GestureDetector(
          onTap: _decreaseQuantity,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.remove,
              size: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Quantity input
        GestureDetector(
          onTap: () {
            setState(() => _isEditing = true);
            _controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controller.text.length,
            );
          },
          child: Container(
            width: 40,
            height: 28,
            alignment: Alignment.center,
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: _onQuantitySubmitted,
                    onTapOutside: (_) {
                      _onQuantitySubmitted(_controller.text);
                    },
                  )
                : Text(
                    widget.quantity.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        // Increase button
        GestureDetector(
          onTap: _increaseQuantity,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: canIncrease ? Colors.grey.shade100 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.add,
              size: 16,
              color: canIncrease ? AppTheme.textPrimary : Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerPickerDialog extends ConsumerStatefulWidget {
  final List<Customer> customers;
  const _CustomerPickerDialog({required this.customers});

  @override
  ConsumerState<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends ConsumerState<_CustomerPickerDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        color: Colors.white,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Text('Select Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: widget.customers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No customers yet', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      thickness: 6,
                      radius: const Radius.circular(3),
                      child: ListView.builder(
                        itemCount: widget.customers.length,
                        itemBuilder: (context, index) {
                          final c = widget.customers[index];
                          return InkWell(
                            onTap: () => Navigator.pop(context, {'id': c.id, 'name': c.name}),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name, 
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Balance: ${formatCurrency(c.balanceCents)}',
                                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAddCustomerDialog(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('New Customer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    // Fetch all customers for duplicate validation
    final allCustomers = await ref.read(databaseProvider).customersDao.searchCustomers('');
    
    if (!context.mounted) return;

    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    const Text('Add Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Customer Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                          const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter customer name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          errorMaxLines: 2,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Customer name is required';
                          if (v!.trim().length > 30) return 'Name must be 30 characters or less';
                          // Check for duplicate
                          final exists = allCustomers.any((c) => c.name.toLowerCase() == v.trim().toLowerCase());
                          if (exists) return 'Customer with this name already exists';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Phone (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: phoneCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter phone number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  try {
                                    final id = await ref.read(customersNotifierProvider.notifier).addCustomer(
                                      name: nameCtrl.text.trim(),
                                      phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) {
                                      Navigator.pop(ctx, {'id': id, 'name': nameCtrl.text.trim()});
                                    }
                                  } catch (e) {
                                    // This shouldn't happen since we validate inline, but just in case
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(e.toString().replaceAll('Exception: ', '')),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Add'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && context.mounted) {
      // Close the customer picker dialog and return the new customer
      Navigator.pop(context, result);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Customer added'),
            ],
          ),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}