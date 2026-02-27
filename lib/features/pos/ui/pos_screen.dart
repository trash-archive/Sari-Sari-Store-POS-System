import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
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
  String _searchQuery = '';
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final productsAsync = _searchQuery.isEmpty
        ? ref.watch(productsProvider)
        : ref.watch(productSearchProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS'),
        actions: [
          if (cart.itemCount > 0)
            IconButton(
              icon: Badge(label: Text('${cart.itemCount}'), child: const Icon(Icons.shopping_cart)),
              onPressed: () => _showCart(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          _buildCategoryFilter(),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final filtered = _selectedCategoryId == null
                    ? products
                    : products.where((p) => p.categoryId == _selectedCategoryId).toList();
                return _ProductGrid(products: filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
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
      builder: (_) => const CartSheet(),
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}

class _ProductGrid extends ConsumerWidget {
  final List<Product> products;
  const _ProductGrid({required this.products});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (products.isEmpty) {
      return const Center(child: Text('No products found'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: outOfStock || maxReached ? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(outOfStock ? 'Out of stock' : 'Maximum quantity reached'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 1),
            ),
          );
        } : () => ref.read(cartProvider.notifier).addItem(product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: product.imagePath != null
                    ? Image.file(File(product.imagePath!), fit: BoxFit.cover, width: double.infinity)
                    : Container(
                        color: Colors.grey.shade100,
                        width: double.infinity,
                        child: const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatCurrency(product.priceCents),
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      if (outOfStock)
                        const Text('Out of stock', style: TextStyle(color: Colors.red, fontSize: 10))
                      else if (maxReached)
                        const Text('Max qty', style: TextStyle(color: Colors.orange, fontSize: 10))
                      else if (inCart != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${inCart.qty}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        )
                      else
                        Text('${product.stockQty} ${product.unit}',
                            style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
    return SafeArea(
      child: GestureDetector(
        onTap: onViewCart,
        child: Container(
          color: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text('${cart.itemCount} items', style: const TextStyle(color: Colors.white)),
              const Spacer(),
              Text(formatCurrency(cart.totalCents),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
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
  final _discountCtrl = TextEditingController();
  int? _cashReceivedCents;
  int? _changeCents;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      builder: (context, scrollCtrl) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Cart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () { ref.read(cartProvider.notifier).clear(); Navigator.pop(context); },
                  child: const Text('Clear', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: cart.items.length,
              itemBuilder: (context, i) => _CartItemTile(item: cart.items[i]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: Column(
              children: [
                Row(children: [
                  const Expanded(child: Text('Subtotal')),
                  Text(formatCurrency(cart.subtotalCents)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(child: Text('Discount (₱)')),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (v) {
                        final amount = double.tryParse(v.isEmpty ? '0' : v) ?? 0;
                        if (amount < 0) return;
                        final cents = parseToCents(v.isEmpty ? '0' : v);
                        if (cents > cart.subtotalCents) {
                          _discountCtrl.text = (cart.subtotalCents / 100).toStringAsFixed(2);
                          ref.read(cartProvider.notifier).setDiscount(cart.subtotalCents);
                        } else {
                          ref.read(cartProvider.notifier).setDiscount(cents);
                        }
                      },
                    ),
                  ),
                ]),
                const Divider(),
                Row(children: [
                  const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  Text(formatCurrency(cart.totalCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF2E7D32))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.payments),
                      label: const Text('Cash'),
                      onPressed: () => _checkout(context, 'cash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.people),
                      label: const Text('Utang'),
                      onPressed: () => _checkout(context, 'utang'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
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
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
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
    final formKey = GlobalKey<FormState>();
    int changeCents = 0;
    int cashReceivedCents = 0;

    final result = await showDialog<Map<String, int>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cash Payment'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontSize: 12)),
                      Text(
                        formatCurrency(cart.totalCents),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: cashCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Cash Received (₱)',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
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
                  const SizedBox(height: 16),
                if (changeCents > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Change:', style: TextStyle(fontSize: 12)),
                        Text(
                          formatCurrency(changeCents),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, {'cash': cashReceivedCents, 'change': changeCents});
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _cashReceivedCents = result['cash'];
      _changeCents = result['change'];
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
    _discountCtrl.dispose();
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
    
    return ListTile(
      title: Text(item.product.name),
      subtitle: Text('${formatCurrency(item.product.priceCents)} · Stock: ${item.product.stockQty}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => notifier.updateQty(item.product.id, item.qty - 1),
          ),
          Text('${item.qty}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: canIncrease ? null : Colors.grey),
            onPressed: canIncrease ? () {
              notifier.updateQty(item.product.id, item.qty + 1);
            } : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cannot exceed available stock'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          Text(formatCurrency(item.lineTotalCents),
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: double.maxFinite,
        child: _creating
            ? Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone (optional)'),
                    ),
                  ],
                ),
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.customers.isEmpty) const Text('No customers yet.'),
                ...widget.customers.map((c) => ListTile(
                  title: Text(c.name),
                  subtitle: Text('${formatCurrency(c.balanceCents)} balance'),
                  onTap: () => Navigator.pop(context, c.id),
                )),
              ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (!_creating)
          TextButton(onPressed: () => setState(() => _creating = true), child: const Text('New Customer')),
        if (_creating)
          ElevatedButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final id = await ref.read(customersNotifierProvider.notifier).addCustomer(
                name: _nameCtrl.text.trim(),
                phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
              );
              if (context.mounted) Navigator.pop(context, id);
            },
            child: const Text('Save'),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }
}