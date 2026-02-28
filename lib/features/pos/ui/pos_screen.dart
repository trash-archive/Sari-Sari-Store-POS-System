import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/utils/currency.dart';
import '../../../data/db/app_database.dart';
import '../../products/state/products_provider.dart';
import '../state/cart_provider.dart';
import '../../utang/state/customers_provider.dart';
import '../../invoices/ui/invoice_detail_screen.dart';
import 'dart:io';

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
  bool _isSearchExpanded = false;
  bool _showFloatingButtons = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && !_showFloatingButtons) {
      setState(() {
        _showFloatingButtons = true;
        _isSearchExpanded = false;
      });
    } else if (_scrollController.offset <= 50 && _showFloatingButtons) {
      setState(() => _showFloatingButtons = false);
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
        title: const Text('Point of Sale', style: TextStyle(fontWeight: FontWeight.w600)),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: TextStyle(color: AppTheme.textSecondary),
                                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
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
                child: productsAsync.when(
                  data: (products) {
                    final filtered = _selectedCategoryId == null
                        ? products
                        : products.where((p) => p.categoryId == _selectedCategoryId).toList();
                    return _ProductGrid(
                      products: filtered,
                      scrollController: _scrollController,
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
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showFloatingButtons ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: _isSearchExpanded ? MediaQuery.of(context).size.width - 100 : 48,
                      height: 48,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(24),
                        color: Colors.white,
                        child: _isSearchExpanded
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _searchCtrl,
                                          autofocus: true,
                                          style: const TextStyle(fontSize: 14),
                                          decoration: const InputDecoration(
                                            hintText: 'Search...',
                                            border: InputBorder.none,
                                            isDense: true,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (v) => setState(() => _searchQuery = v),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _isSearchExpanded = false;
                                            _searchQuery = '';
                                            _searchCtrl.clear();
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : InkWell(
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
                    ),
                    const SizedBox(height: 12),
                    _buildFloatingCategoryButton(),
                  ],
                ),
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
          decoration: BoxDecoration(
            color: _selectedCategoryId != null ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: false,
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
                      color: _selectedCategoryId == null ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: _selectedCategoryId == null ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                  title: const Text('All Categories', style: TextStyle(fontWeight: FontWeight.w500)),
                  selected: _selectedCategoryId == null,
                  selectedTileColor: AppTheme.primary.withOpacity(0.05),
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
                      color: _selectedCategoryId == cat.id ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.category_outlined,
                      color: _selectedCategoryId == cat.id ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  selected: _selectedCategoryId == cat.id,
                  selectedTileColor: AppTheme.primary.withOpacity(0.05),
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
  const _ProductGrid({required this.products, required this.scrollController});

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
    final cart = ref.watch(cartProvider);
    final inCart = cart.items.where((i) => i.product.id == product.id).firstOrNull;
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
                content: Text(outOfStock ? 'Out of stock' : 'Maximum quantity reached'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
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
                      child: product.imagePath != null
                          ? Image.file(
                              File(product.imagePath!),
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
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
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
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: cart.items.length,
                      itemBuilder: (context, i) => _CartItemTile(item: cart.items[i]),
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

    if (type == 'utang') {
      customerId = await _selectOrCreateCustomer(context);
      if (customerId == null) return;
    } else if (type == 'cash') {
      final proceed = await _showCashPaymentDialog(context);
      if (proceed != true) return;
    }

    final invoice = await ref.read(cartProvider.notifier).checkout(
      type: type,
      customerId: customerId,
      notes: _cashPayerName ?? (_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
      cashReceivedCents: _cashReceivedCents,
      changeCents: _changeCents,
    );

    if (!context.mounted) return;
    Navigator.pop(context);

    if (invoice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${invoice.invoiceNo} — ${formatCurrency(invoice.totalCents)}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<bool?> _showCashPaymentDialog(BuildContext context) async {
    final cart = ref.read(cartProvider);
    final cashCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int changeCents = 0;
    int cashReceivedCents = 0;
    bool showNameField = false;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
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
                            const Text('Total Amount', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            Text(
                              formatCurrency(cart.totalCents),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: cashCtrl,
                          autofocus: true,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Cash Received',
                            prefixText: '₱ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'Required';
                            final amount = double.tryParse(v!);
                            if (amount == null) return 'Invalid amount';
                            final cents = (amount * 100).round();
                            if (cents < cart.totalCents) return 'Insufficient amount';
                            return null;
                          },
                          onChanged: (v) {
                            final amount = double.tryParse(v);
                            if (amount != null) {
                              final cents = (amount * 100).round();
                              setState(() {
                                cashReceivedCents = cents;
                                changeCents = (cents - cart.totalCents).clamp(0, 999999999);
                              });
                            } else {
                              setState(() {
                                cashReceivedCents = 0;
                                changeCents = 0;
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
                        const SizedBox(height: 16),
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
                        if (showNameField)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextFormField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Customer Name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
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
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    Navigator.pop(ctx, {
                                      'cash': cashReceivedCents,
                                      'change': changeCents,
                                      'name': nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                                    });
                                  }
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
    );

    if (result != null) {
      _cashReceivedCents = result['cash'];
      _changeCents = result['change'];
      _cashPayerName = result['name'];
      return true;
    }
    return false;
  }

  Future<String?> _selectOrCreateCustomer(BuildContext context) async {
    final customers = await ref.read(databaseProvider).customersDao
        .searchCustomers('');

    if (!context.mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (ctx) => _CustomerPickerDialog(customers: customers),
    );
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
    final canIncrease = item.qty < item.product.stockQty;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCurrency(item.product.priceCents)} × ${item.qty}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  onPressed: () => notifier.updateQty(item.product.id, item.qty - 1),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${item.qty}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: Icon(Icons.add, size: 18, color: canIncrease ? AppTheme.textPrimary : Colors.grey),
                  onPressed: canIncrease ? () {
                    notifier.updateQty(item.product.id, item.qty + 1);
                  } : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cannot exceed available stock'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatCurrency(item.lineTotalCents),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
          ),
        ],
      ),
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
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        color: Colors.white,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
            Flexible(
              child: _creating
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Customer Name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) => v?.trim().isEmpty ?? true ? 'Name is required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneCtrl,
                              decoration: InputDecoration(
                                labelText: 'Phone (optional)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.customers.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text('No customers yet', style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        else
                          ...widget.customers.map((c) => InkWell(
                            onTap: () => Navigator.pop(context, c.id),
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
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
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
                      onPressed: _creating
                          ? () async {
                              if (!_formKey.currentState!.validate()) return;
                              final id = await ref.read(customersNotifierProvider.notifier).addCustomer(
                                name: _nameCtrl.text.trim(),
                                phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
                              );
                              if (context.mounted) Navigator.pop(context, id);
                            }
                          : () => setState(() => _creating = true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_creating ? 'Save' : 'New Customer'),
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }
}