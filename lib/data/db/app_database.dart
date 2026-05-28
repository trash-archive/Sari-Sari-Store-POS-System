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
      if (from < 5) {
        await m.addColumn(products, products.imageData);
      }
      if (from < 6) {
        await m.addColumn(products, products.imageUrl);
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

  Future<void> _seedProducts() async {
    final cats = await select(categories).get();
    final catMap = {for (var c in cats) c.name: c.id};

    final sampleProducts = [
      // Beverages
      {'name': 'Coca-Cola 330ml', 'price': 2500, 'stock': 50, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'Sprite 330ml', 'price': 2500, 'stock': 45, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'Royal 330ml', 'price': 2500, 'stock': 40, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'C2 Green Tea', 'price': 2000, 'stock': 30, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'Zesto Orange', 'price': 1500, 'stock': 25, 'category': 'Beverages', 'unit': 'bottle'},
      
      // Snacks
      {'name': 'Chippy BBQ', 'price': 1000, 'stock': 60, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Piattos Cheese', 'price': 1200, 'stock': 55, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Nova Multigrain', 'price': 800, 'stock': 70, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Richeese Nabati', 'price': 500, 'stock': 80, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Boy Bawang', 'price': 600, 'stock': 65, 'category': 'Snacks', 'unit': 'pack'},
      
      // Canned Goods
      {'name': 'Century Tuna Flakes', 'price': 3500, 'stock': 35, 'category': 'Canned Goods', 'unit': 'can'},
      {'name': 'Ligo Sardines', 'price': 2800, 'stock': 40, 'category': 'Canned Goods', 'unit': 'can'},
      {'name': 'CDO Corned Beef', 'price': 4500, 'stock': 25, 'category': 'Canned Goods', 'unit': 'can'},
      {'name': 'Argentina Corned Beef', 'price': 3800, 'stock': 30, 'category': 'Canned Goods', 'unit': 'can'},
      
      // Personal Care
      {'name': 'Safeguard Soap', 'price': 2200, 'stock': 45, 'category': 'Personal Care', 'unit': 'bar'},
      {'name': 'Colgate Toothpaste', 'price': 3500, 'stock': 20, 'category': 'Personal Care', 'unit': 'tube'},
      {'name': 'Head & Shoulders', 'price': 1500, 'stock': 15, 'category': 'Personal Care', 'unit': 'sachet'},
      {'name': 'Close Up Toothpaste', 'price': 3200, 'stock': 18, 'category': 'Personal Care', 'unit': 'tube'},
      
      // Condiments
      {'name': 'Silver Swan Soy Sauce', 'price': 2800, 'stock': 25, 'category': 'Condiments', 'unit': 'bottle'},
      {'name': 'Datu Puti Vinegar', 'price': 2500, 'stock': 30, 'category': 'Condiments', 'unit': 'bottle'},
      {'name': 'UFC Banana Catsup', 'price': 3200, 'stock': 20, 'category': 'Condiments', 'unit': 'bottle'},
      {'name': 'Maggi Magic Sarap', 'price': 800, 'stock': 50, 'category': 'Condiments', 'unit': 'sachet'},
      
      // Dairy
      {'name': 'Alaska Milk', 'price': 4500, 'stock': 15, 'category': 'Dairy', 'unit': 'can'},
      {'name': 'Bear Brand Milk', 'price': 2200, 'stock': 25, 'category': 'Dairy', 'unit': 'can'},
      {'name': 'Eden Cheese', 'price': 8500, 'stock': 10, 'category': 'Dairy', 'unit': 'pack'},
      
      // Bread & Bakery
      {'name': 'Gardenia Bread', 'price': 5500, 'stock': 12, 'category': 'Bread & Bakery', 'unit': 'loaf'},
      {'name': 'Pandesal', 'price': 300, 'stock': 50, 'category': 'Bread & Bakery', 'unit': 'piece'},
      {'name': 'Skyflakes Crackers', 'price': 2800, 'stock': 20, 'category': 'Bread & Bakery', 'unit': 'pack'},
      
      // Others
      {'name': 'Lucky Me Pancit Canton', 'price': 1200, 'stock': 100, 'category': 'Others', 'unit': 'pack'},
      {'name': 'Rice (Bigas)', 'price': 5500, 'stock': 8, 'category': 'Others', 'unit': 'kg'},
      {'name': 'Eggs', 'price': 800, 'stock': 60, 'category': 'Others', 'unit': 'piece'},
      {'name': 'Cooking Oil', 'price': 12000, 'stock': 5, 'category': 'Others', 'unit': 'bottle'},
    ];

    for (final product in sampleProducts) {
      final id = DateTime.now().microsecondsSinceEpoch.toString() + product['name'].hashCode.toString();
      await into(products).insert(ProductsCompanion(
        id: Value(id),
        name: Value(product['name'] as String),
        priceCents: Value(product['price'] as int),
        stockQty: Value(product['stock'] as int),
        categoryId: Value(catMap[product['category']]!),
        unit: Value(product['unit'] as String),
        lowStockThreshold: const Value(5),
      ));
    }
  }

  Future<void> addSampleProducts() async {
    final cats = await select(categories).get();
    final catMap = {for (var c in cats) c.name: c.id};

    final sampleProducts = [
      // Beverages
      {'name': 'Coca-Cola 330ml', 'price': 2500, 'stock': 50, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'Sprite 330ml', 'price': 2500, 'stock': 45, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'Royal 330ml', 'price': 2500, 'stock': 40, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'C2 Green Tea', 'price': 2000, 'stock': 30, 'category': 'Beverages', 'unit': 'bottle'},
      {'name': 'Zesto Orange', 'price': 1500, 'stock': 25, 'category': 'Beverages', 'unit': 'bottle'},
      
      // Snacks
      {'name': 'Chippy BBQ', 'price': 1000, 'stock': 60, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Piattos Cheese', 'price': 1200, 'stock': 55, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Nova Multigrain', 'price': 800, 'stock': 70, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Richeese Nabati', 'price': 500, 'stock': 80, 'category': 'Snacks', 'unit': 'pack'},
      {'name': 'Boy Bawang', 'price': 600, 'stock': 65, 'category': 'Snacks', 'unit': 'pack'},
      
      // Canned Goods
      {'name': 'Century Tuna Flakes', 'price': 3500, 'stock': 35, 'category': 'Canned Goods', 'unit': 'can'},
      {'name': 'Ligo Sardines', 'price': 2800, 'stock': 40, 'category': 'Canned Goods', 'unit': 'can'},
      {'name': 'CDO Corned Beef', 'price': 4500, 'stock': 25, 'category': 'Canned Goods', 'unit': 'can'},
      {'name': 'Argentina Corned Beef', 'price': 3800, 'stock': 30, 'category': 'Canned Goods', 'unit': 'can'},
      
      // Personal Care
      {'name': 'Safeguard Soap', 'price': 2200, 'stock': 45, 'category': 'Personal Care', 'unit': 'bar'},
      {'name': 'Colgate Toothpaste', 'price': 3500, 'stock': 20, 'category': 'Personal Care', 'unit': 'tube'},
      {'name': 'Head & Shoulders', 'price': 1500, 'stock': 15, 'category': 'Personal Care', 'unit': 'sachet'},
      {'name': 'Close Up Toothpaste', 'price': 3200, 'stock': 18, 'category': 'Personal Care', 'unit': 'tube'},
      
      // Condiments
      {'name': 'Silver Swan Soy Sauce', 'price': 2800, 'stock': 25, 'category': 'Condiments', 'unit': 'bottle'},
      {'name': 'Datu Puti Vinegar', 'price': 2500, 'stock': 30, 'category': 'Condiments', 'unit': 'bottle'},
      {'name': 'UFC Banana Catsup', 'price': 3200, 'stock': 20, 'category': 'Condiments', 'unit': 'bottle'},
      {'name': 'Maggi Magic Sarap', 'price': 800, 'stock': 50, 'category': 'Condiments', 'unit': 'sachet'},
      
      // Dairy
      {'name': 'Alaska Milk', 'price': 4500, 'stock': 15, 'category': 'Dairy', 'unit': 'can'},
      {'name': 'Bear Brand Milk', 'price': 2200, 'stock': 25, 'category': 'Dairy', 'unit': 'can'},
      {'name': 'Eden Cheese', 'price': 8500, 'stock': 10, 'category': 'Dairy', 'unit': 'pack'},
      
      // Bread & Bakery
      {'name': 'Gardenia Bread', 'price': 5500, 'stock': 12, 'category': 'Bread & Bakery', 'unit': 'loaf'},
      {'name': 'Pandesal', 'price': 300, 'stock': 50, 'category': 'Bread & Bakery', 'unit': 'piece'},
      {'name': 'Skyflakes Crackers', 'price': 2800, 'stock': 20, 'category': 'Bread & Bakery', 'unit': 'pack'},
      
      // Others
      {'name': 'Lucky Me Pancit Canton', 'price': 1200, 'stock': 100, 'category': 'Others', 'unit': 'pack'},
      {'name': 'Rice (Bigas)', 'price': 5500, 'stock': 8, 'category': 'Others', 'unit': 'kg'},
      {'name': 'Eggs', 'price': 800, 'stock': 60, 'category': 'Others', 'unit': 'piece'},
      {'name': 'Cooking Oil', 'price': 12000, 'stock': 5, 'category': 'Others', 'unit': 'bottle'},
    ];

    for (final product in sampleProducts) {
      final id = DateTime.now().microsecondsSinceEpoch.toString() + product['name'].hashCode.toString();
      await into(products).insert(ProductsCompanion(
        id: Value(id),
        name: Value(product['name'] as String),
        priceCents: Value(product['price'] as int),
        stockQty: Value(product['stock'] as int),
        categoryId: Value(catMap[product['category']]!),
        unit: Value(product['unit'] as String),
        lowStockThreshold: const Value(5),
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