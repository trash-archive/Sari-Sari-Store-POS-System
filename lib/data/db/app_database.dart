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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedData();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(invoices, invoices.cashReceivedCents);
        await m.addColumn(invoices, invoices.changeCents);
      }
    },
  );

  Future<void> _seedData() async {
    // Seed default categories
    final defaultCategories = [
      'Beverages', 'Snacks', 'Canned Goods', 'Personal Care',
      'Condiments', 'Dairy', 'Bread & Bakery', 'Others',
    ];

    final categoryIds = <String, String>{};
    for (final name in defaultCategories) {
      final id = DateTime.now().microsecondsSinceEpoch.toString() + name.hashCode.toString();
      await into(categories).insert(CategoriesCompanion(
        id: Value(id),
        name: Value(name),
      ));
      categoryIds[name] = id;
    }

    // Seed sample products
    final sampleProducts = [
      // Beverages
      {'name': 'Coca-Cola 1.5L', 'category': 'Beverages', 'price': 65.00, 'cost': 50.00, 'stock': 24, 'unit': 'btl'},
      {'name': 'Sprite 1.5L', 'category': 'Beverages', 'price': 65.00, 'cost': 50.00, 'stock': 18, 'unit': 'btl'},
      {'name': 'Royal 1.5L', 'category': 'Beverages', 'price': 65.00, 'cost': 50.00, 'stock': 15, 'unit': 'btl'},
      {'name': 'C2 Green Tea 1L', 'category': 'Beverages', 'price': 35.00, 'cost': 28.00, 'stock': 30, 'unit': 'btl'},
      {'name': 'Zest-O Orange 200ml', 'category': 'Beverages', 'price': 12.00, 'cost': 9.00, 'stock': 48, 'unit': 'pc'},
      {'name': 'Nescafe 3-in-1 Original', 'category': 'Beverages', 'price': 8.00, 'cost': 6.50, 'stock': 100, 'unit': 'sachet'},
      {'name': 'Milo Sachet', 'category': 'Beverages', 'price': 10.00, 'cost': 8.00, 'stock': 80, 'unit': 'sachet'},
      
      // Snacks
      {'name': 'Chippy BBQ', 'category': 'Snacks', 'price': 8.00, 'cost': 6.00, 'stock': 50, 'unit': 'pc'},
      {'name': 'Piattos Cheese', 'category': 'Snacks', 'price': 15.00, 'cost': 12.00, 'stock': 40, 'unit': 'pc'},
      {'name': 'Nova', 'category': 'Snacks', 'price': 8.00, 'cost': 6.00, 'stock': 45, 'unit': 'pc'},
      {'name': 'Skyflakes Crackers', 'category': 'Snacks', 'price': 35.00, 'cost': 28.00, 'stock': 20, 'unit': 'pack'},
      {'name': 'Oishi Prawn Crackers', 'category': 'Snacks', 'price': 8.00, 'cost': 6.00, 'stock': 60, 'unit': 'pc'},
      {'name': 'Clover Chips', 'category': 'Snacks', 'price': 8.00, 'cost': 6.00, 'stock': 35, 'unit': 'pc'},
      {'name': 'Peanuts Garlic', 'category': 'Snacks', 'price': 5.00, 'cost': 3.50, 'stock': 70, 'unit': 'pack'},
      
      // Canned Goods
      {'name': 'Century Tuna Flakes', 'category': 'Canned Goods', 'price': 35.00, 'cost': 28.00, 'stock': 30, 'unit': 'can'},
      {'name': 'Argentina Corned Beef', 'category': 'Canned Goods', 'price': 45.00, 'cost': 38.00, 'stock': 25, 'unit': 'can'},
      {'name': 'Ligo Sardines Red', 'category': 'Canned Goods', 'price': 25.00, 'cost': 20.00, 'stock': 40, 'unit': 'can'},
      {'name': '555 Sardines Green', 'category': 'Canned Goods', 'price': 22.00, 'cost': 18.00, 'stock': 35, 'unit': 'can'},
      {'name': 'Mega Sardines', 'category': 'Canned Goods', 'price': 18.00, 'cost': 14.00, 'stock': 50, 'unit': 'can'},
      {'name': 'CDO Liver Spread', 'category': 'Canned Goods', 'price': 28.00, 'cost': 22.00, 'stock': 20, 'unit': 'can'},
      
      // Personal Care
      {'name': 'Safeguard Bar Soap', 'category': 'Personal Care', 'price': 35.00, 'cost': 28.00, 'stock': 30, 'unit': 'pc'},
      {'name': 'Palmolive Shampoo Sachet', 'category': 'Personal Care', 'price': 8.00, 'cost': 6.00, 'stock': 100, 'unit': 'sachet'},
      {'name': 'Colgate Toothpaste 50g', 'category': 'Personal Care', 'price': 45.00, 'cost': 38.00, 'stock': 15, 'unit': 'pc'},
      {'name': 'Close-Up Toothpaste', 'category': 'Personal Care', 'price': 42.00, 'cost': 35.00, 'stock': 18, 'unit': 'pc'},
      {'name': 'Head & Shoulders Sachet', 'category': 'Personal Care', 'price': 10.00, 'cost': 8.00, 'stock': 80, 'unit': 'sachet'},
      {'name': 'Tide Detergent Powder 50g', 'category': 'Personal Care', 'price': 12.00, 'cost': 9.00, 'stock': 60, 'unit': 'pack'},
      
      // Condiments
      {'name': 'Silver Swan Soy Sauce 385ml', 'category': 'Condiments', 'price': 28.00, 'cost': 22.00, 'stock': 20, 'unit': 'btl'},
      {'name': 'Datu Puti Vinegar 385ml', 'category': 'Condiments', 'price': 22.00, 'cost': 18.00, 'stock': 25, 'unit': 'btl'},
      {'name': 'UFC Banana Catsup 320g', 'category': 'Condiments', 'price': 35.00, 'cost': 28.00, 'stock': 18, 'unit': 'btl'},
      {'name': 'Mama Sita Oyster Sauce', 'category': 'Condiments', 'price': 32.00, 'cost': 26.00, 'stock': 15, 'unit': 'btl'},
      {'name': 'Ajinomoto Umami Seasoning', 'category': 'Condiments', 'price': 8.00, 'cost': 6.00, 'stock': 50, 'unit': 'pack'},
      {'name': 'Magic Sarap 8g', 'category': 'Condiments', 'price': 5.00, 'cost': 3.50, 'stock': 100, 'unit': 'sachet'},
      
      // Dairy
      {'name': 'Alaska Evap Milk 370ml', 'category': 'Dairy', 'price': 55.00, 'cost': 45.00, 'stock': 24, 'unit': 'can'},
      {'name': 'Bear Brand 300ml', 'category': 'Dairy', 'price': 48.00, 'cost': 40.00, 'stock': 30, 'unit': 'can'},
      {'name': 'Nestle Fresh Milk 1L', 'category': 'Dairy', 'price': 85.00, 'cost': 72.00, 'stock': 12, 'unit': 'pack'},
      {'name': 'Eden Cheese 165g', 'category': 'Dairy', 'price': 75.00, 'cost': 62.00, 'stock': 10, 'unit': 'pc'},
      {'name': 'Anchor Butter 200g', 'category': 'Dairy', 'price': 120.00, 'cost': 100.00, 'stock': 8, 'unit': 'pc'},
      
      // Bread & Bakery
      {'name': 'Gardenia Classic White Bread', 'category': 'Bread & Bakery', 'price': 55.00, 'cost': 45.00, 'stock': 15, 'unit': 'loaf'},
      {'name': 'Gardenia Wheat Bread', 'category': 'Bread & Bakery', 'price': 60.00, 'cost': 50.00, 'stock': 12, 'unit': 'loaf'},
      {'name': 'Pandesal 10pcs', 'category': 'Bread & Bakery', 'price': 35.00, 'cost': 25.00, 'stock': 20, 'unit': 'pack'},
      {'name': 'Rebisco Crackers', 'category': 'Bread & Bakery', 'price': 25.00, 'cost': 20.00, 'stock': 30, 'unit': 'pack'},
      
      // Others
      {'name': 'Lucky Me Pancit Canton', 'category': 'Others', 'price': 15.00, 'cost': 12.00, 'stock': 60, 'unit': 'pack'},
      {'name': 'Payless Instant Noodles', 'category': 'Others', 'price': 8.00, 'cost': 6.00, 'stock': 80, 'unit': 'pack'},
      {'name': 'Egg Medium Size', 'category': 'Others', 'price': 8.00, 'cost': 6.50, 'stock': 60, 'unit': 'pc'},
      {'name': 'Rice 1kg', 'category': 'Others', 'price': 55.00, 'cost': 48.00, 'stock': 50, 'unit': 'kg'},
      {'name': 'Cooking Oil 1L', 'category': 'Others', 'price': 85.00, 'cost': 72.00, 'stock': 20, 'unit': 'btl'},
      {'name': 'White Sugar 1kg', 'category': 'Others', 'price': 65.00, 'cost': 55.00, 'stock': 25, 'unit': 'kg'},
      {'name': 'Iodized Salt 1kg', 'category': 'Others', 'price': 25.00, 'cost': 20.00, 'stock': 30, 'unit': 'kg'},
    ];

    for (final product in sampleProducts) {
      final catId = categoryIds[product['category'] as String];
      if (catId != null) {
        await into(products).insert(ProductsCompanion(
          id: Value(DateTime.now().microsecondsSinceEpoch.toString() + product['name'].hashCode.toString()),
          name: Value(product['name'] as String),
          categoryId: Value(catId),
          priceCents: Value(((product['price'] as double) * 100).round()),
          costCents: Value(((product['cost'] as double) * 100).round()),
          stockQty: Value(product['stock'] as int),
          unit: Value(product['unit'] as String),
          lowStockThreshold: Value(10),
        ));
      }
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'sari_pos_db', web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ));
  }
}