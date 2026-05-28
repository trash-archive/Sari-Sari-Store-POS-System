import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/categories_table.dart';
import 'tables/products_table.dart';
import 'tables/customers_table.dart';
import 'tables/invoices_table.dart';
import 'tables/invoice_items_table.dart';
import 'tables/customer_payments_table.dart';
import 'tables/stock_movements_table.dart';
import 'daos/products_dao.dart';
import 'daos/invoices_dao.dart';
import 'daos/customers_dao.dart';
import 'daos/reports_dao.dart';

export 'tables/categories_table.dart';
export 'tables/products_table.dart';
export 'tables/customers_table.dart';
export 'tables/invoices_table.dart';
export 'tables/invoice_items_table.dart';
export 'tables/customer_payments_table.dart';
export 'tables/stock_movements_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    Products,
    Customers,
    Invoices,
    InvoiceItems,
    CustomerPayments,
    StockMovements,
  ],
  daos: [
    ProductsDao,
    InvoicesDao,
    CustomersDao,
    ReportsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategories();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(invoices, invoices.cashReceivedCents);
        await m.addColumn(invoices, invoices.changeCents);
      }
      if (from < 3) {
        await m.addColumn(customerPayments, customerPayments.invoiceId);
      }
      if (from < 4) {
        final nowUs = DateTime.now().microsecondsSinceEpoch;
        // Categories
        await m.issueCustomQuery('ALTER TABLE "categories" ADD COLUMN "updated_at" INTEGER NOT NULL DEFAULT 0');
        await m.issueCustomQuery('UPDATE "categories" SET "updated_at" = $nowUs');
        await m.addColumn(categories, categories.syncId);
        await m.addColumn(categories, categories.deletedAt);
        await m.addColumn(categories, categories.isSynced);
        // Products
        await m.addColumn(products, products.syncId);
        await m.addColumn(products, products.deletedAt);
        await m.addColumn(products, products.isSynced);
        // Customers
        await m.addColumn(customers, customers.syncId);
        await m.addColumn(customers, customers.deletedAt);
        await m.addColumn(customers, customers.isSynced);
        // Invoices
        await m.issueCustomQuery('ALTER TABLE "invoices" ADD COLUMN "updated_at" INTEGER NOT NULL DEFAULT 0');
        await m.issueCustomQuery('UPDATE "invoices" SET "updated_at" = $nowUs');
        await m.addColumn(invoices, invoices.syncId);
        await m.addColumn(invoices, invoices.deletedAt);
        await m.addColumn(invoices, invoices.isSynced);
        // InvoiceItems
        await m.addColumn(invoiceItems, invoiceItems.syncId);
        await m.addColumn(invoiceItems, invoiceItems.isSynced);
        // CustomerPayments
        await m.addColumn(customerPayments, customerPayments.syncId);
        await m.addColumn(customerPayments, customerPayments.isSynced);
        // StockMovements
        await m.addColumn(stockMovements, stockMovements.syncId);
        await m.addColumn(stockMovements, stockMovements.isSynced);
      }
      if (from < 5) {
        await m.addColumn(products, products.imageData);
      }
      if (from < 6) {
        await m.addColumn(products, products.imageUrl);
      }
    },
  );

  Future<void> _seedCategories() async {
    final defaultCategories = [
      'Beverages', 'Snacks', 'Canned Goods', 'Personal Care',
      'Condiments', 'Dairy', 'Bread & Bakery', 'Others',
    ];

    for (final name in defaultCategories) {
      final id = DateTime.now().microsecondsSinceEpoch.toString() + name.hashCode.toString();
      await into(categories).insert(CategoriesCompanion(
        id: Value(id),
        name: Value(name),
      ));
    }
  }

  /// Resets all sync state so data is re-synced for a new user account.
  Future<void> clearSyncState() async {
    await customStatement('UPDATE categories SET sync_id = NULL, is_synced = 0');
    await customStatement('UPDATE products SET sync_id = NULL, is_synced = 0');
    await customStatement('UPDATE customers SET sync_id = NULL, is_synced = 0');
    await customStatement('UPDATE invoices SET sync_id = NULL, is_synced = 0');
    await customStatement('UPDATE invoice_items SET sync_id = NULL, is_synced = 0');
    await customStatement('UPDATE customer_payments SET sync_id = NULL, is_synced = 0');
    await customStatement('UPDATE stock_movements SET sync_id = NULL, is_synced = 0');
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'sari_pos_db', web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ));
  }
}