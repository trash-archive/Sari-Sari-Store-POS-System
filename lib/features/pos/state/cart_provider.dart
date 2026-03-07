import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../app/providers.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/db/app_database.dart';

const _uuid = Uuid();

class CartItem {
  final Product product;
  final int qty;

  CartItem({required this.product, required this.qty});

  CartItem copyWith({int? qty}) => CartItem(product: product, qty: qty ?? this.qty);

  int get lineTotalCents => product.priceCents * qty;
}

class CartState {
  final List<CartItem> items;
  final int discountCents;

  CartState({this.items = const [], this.discountCents = 0});

  int get subtotalCents => items.fold(0, (sum, i) => sum + i.lineTotalCents);
  int get totalCents => (subtotalCents - discountCents).clamp(0, 999999999);
  int get itemCount => items.fold(0, (sum, i) => sum + i.qty);

  CartState copyWith({List<CartItem>? items, int? discountCents}) =>
      CartState(
        items: items ?? this.items,
        discountCents: discountCents ?? this.discountCents,
      );
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => CartState();

  void addItem(Product product) {
    // Validation: Check if product is out of stock
    if (product.stockQty <= 0) {
      return; // Don't add out of stock items
    }
    
    final existing = state.items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      final newQty = state.items[existing].qty + 1;
      // Validation: Check if new quantity exceeds available stock
      if (newQty > product.stockQty) {
        return; // Don't exceed available stock
      }
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(qty: newQty);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [...state.items, CartItem(product: product, qty: 1)]);
    }
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.product.id != productId).toList(),
    );
  }

  void updateQty(String productId, int qty) {
    if (qty <= 0) {
      removeItem(productId);
      return;
    }
    // Validation: Check stock availability
    final item = state.items.firstWhere((i) => i.product.id == productId);
    if (qty > item.product.stockQty) {
      return; // Don't exceed available stock
    }
    final updated = state.items.map((i) =>
      i.product.id == productId ? i.copyWith(qty: qty) : i).toList();
    state = state.copyWith(items: updated);
  }

  void setDiscount(int cents) {
    state = state.copyWith(discountCents: cents);
  }

  void clear() {
    state = CartState();
  }

  Future<Invoice?> checkout({
    required String type, // 'cash' | 'utang'
    String? customerId,
    String? notes,
    int? cashReceivedCents,
    int? changeCents,
    String? photoPath,
  }) async {
    if (state.items.isEmpty) return null;
    
    // Validation: Check all items have sufficient stock
    for (final item in state.items) {
      if (item.qty > item.product.stockQty) {
        return null; // Insufficient stock
      }
    }
    
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final invoiceNum = await db.invoicesDao.getNextInvoiceNumber();
    final invoiceNo = '${AppConstants.invoicePrefix}-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${invoiceNum.toString().padLeft(4,'0')}';
    final invoiceId = _uuid.v4();

    final invoiceData = InvoicesCompanion(
      id: Value(invoiceId),
      invoiceNo: Value(invoiceNo),
      type: Value(type),
      customerId: Value(customerId),
      subtotalCents: Value(state.subtotalCents),
      discountCents: Value(state.discountCents),
      totalCents: Value(state.totalCents),
      cashReceivedCents: Value(cashReceivedCents),
      changeCents: Value(changeCents),
      notes: Value(notes),
      photoPath: Value(photoPath),
      createdAt: Value(now),
    );

    final items = state.items.map((i) => InvoiceItemsCompanion(
      id: Value(_uuid.v4()),
      invoiceId: Value(invoiceId),
      productId: Value(i.product.id),
      productNameSnapshot: Value(i.product.name),
      unitSnapshot: Value(i.product.unit),
      priceSnapshotCents: Value(i.product.priceCents),
      qty: Value(i.qty),
      lineTotalCents: Value(i.lineTotalCents),
    )).toList();

    final movements = state.items.map((i) => StockMovementsCompanion(
      id: Value(_uuid.v4()),
      productId: Value(i.product.id),
      changeQty: Value(-i.qty),
      reason: const Value('sale'),
      referenceId: Value(invoiceId),
    )).toList();

    final stockUpdates = <String, int>{};
    for (final item in state.items) {
      stockUpdates[item.product.id] = item.product.stockQty - item.qty;
    }

    final invoice = await db.invoicesDao.checkout(
      invoiceData: invoiceData,
      items: items,
      movements: movements,
      stockUpdates: stockUpdates,
      customerId: type == 'utang' ? customerId : null,
      customerBalanceIncrease: type == 'utang' ? state.totalCents : null,
    );

    clear();
    return invoice;
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);