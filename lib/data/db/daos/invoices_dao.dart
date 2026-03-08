import 'package:drift/drift.dart';
import '../app_database.dart';

part 'invoices_dao.g.dart';

@DriftAccessor(tables: [Invoices, InvoiceItems, StockMovements, Customers])
class InvoicesDao extends DatabaseAccessor<AppDatabase> with _$InvoicesDaoMixin {
  InvoicesDao(super.db);

  Stream<List<Invoice>> watchAllInvoices() =>
      (select(db.invoices)
        ..where((i) => i.status.equals('active'))
        ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).watch();

  Future<List<Invoice>> getInvoicesByDateRange(DateTime from, DateTime to) =>
      (select(db.invoices)
        ..where((i) =>
          i.status.equals('active') &
          i.createdAt.isBiggerOrEqualValue(from) &
          i.createdAt.isSmallerOrEqualValue(to)))
      .get();

  Future<Invoice?> getInvoiceById(String id) =>
      (select(db.invoices)..where((i) => i.id.equals(id))).getSingleOrNull();

  Future<List<InvoiceItem>> getItemsForInvoice(String invoiceId) =>
      (select(db.invoiceItems)..where((i) => i.invoiceId.equals(invoiceId))).get();

  Future<List<Invoice>> getUtangInvoicesForCustomer(String customerId) =>
      (select(db.invoices)
        ..where((i) =>
          i.customerId.equals(customerId) &
          i.type.equals('utang'))
        ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).get();

  // Checkout transaction
  Future<Invoice> checkout({
    required InvoicesCompanion invoiceData,
    required List<InvoiceItemsCompanion> items,
    required List<StockMovementsCompanion> movements,
    required Map<String, int> stockUpdates, // productId -> newQty
    String? customerId,
    int? customerBalanceIncrease,
  }) async {
    return db.transaction(() async {
      final invoice = await into(db.invoices).insertReturning(invoiceData);

      for (final item in items) {
        await into(db.invoiceItems).insert(item);
      }

      for (final movement in movements) {
        await into(db.stockMovements).insert(movement);
      }

      for (final entry in stockUpdates.entries) {
        await (update(db.products)..where((p) => p.id.equals(entry.key)))
          .write(ProductsCompanion(stockQty: Value(entry.value)));
      }

      if (customerId != null && customerBalanceIncrease != null) {
        final customer = await (select(db.customers)
          ..where((c) => c.id.equals(customerId))).getSingle();
        await (update(db.customers)..where((c) => c.id.equals(customerId)))
          .write(CustomersCompanion(
            balanceCents: Value(customer.balanceCents + customerBalanceIncrease),
            updatedAt: Value(DateTime.now()),
          ));
      }

      return invoice;
    });
  }

  Future<void> voidInvoice(String invoiceId) async {
    await db.transaction(() async {
      final invoice = await getInvoiceById(invoiceId);
      if (invoice == null) return;

      final items = await getItemsForInvoice(invoiceId);

      // Reverse stock
      for (final item in items) {
        final product = await (select(db.products)
          ..where((p) => p.id.equals(item.productId))).getSingleOrNull();
        if (product != null) {
          await (update(db.products)..where((p) => p.id.equals(item.productId)))
            .write(ProductsCompanion(stockQty: Value(product.stockQty + item.qty)));

          await into(db.stockMovements).insert(StockMovementsCompanion(
            id: Value(DateTime.now().millisecondsSinceEpoch.toString()),
            productId: Value(item.productId),
            changeQty: Value(item.qty),
            reason: const Value('void'),
            referenceId: Value(invoiceId),
          ));
        }
      }

      // Handle customer balance
      if (invoice.customerId != null) {
        final customer = await (select(db.customers)
          ..where((c) => c.id.equals(invoice.customerId!))).getSingleOrNull();
        if (customer != null) {
          int newBalance;
          if (invoice.type == 'utang') {
            // Reduce balance for voided utang
            newBalance = (customer.balanceCents - invoice.totalCents).clamp(0, 999999999);
          } else if (invoice.type == 'payment') {
            // Increase balance for voided payment
            newBalance = customer.balanceCents + invoice.totalCents;
          } else {
            newBalance = customer.balanceCents;
          }
          await (update(db.customers)..where((c) => c.id.equals(customer.id)))
            .write(CustomersCompanion(
              balanceCents: Value(newBalance),
              updatedAt: Value(DateTime.now()),
            ));
        }
      }

      await (update(db.invoices)..where((i) => i.id.equals(invoiceId)))
        .write(const InvoicesCompanion(status: Value('voided')));
    });
  }

  Future<int> getNextInvoiceNumber() async {
    final result = await customSelect(
      'SELECT COUNT(*) as cnt FROM invoices',
      readsFrom: {db.invoices},
    ).getSingle();
    return (result.data['cnt'] as int) + 1;
  }
}