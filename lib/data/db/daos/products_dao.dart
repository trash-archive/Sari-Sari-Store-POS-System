import 'package:drift/drift.dart';
import '../app_database.dart';

part 'products_dao.g.dart';

@DriftAccessor(tables: [Products, Categories])
class ProductsDao extends DatabaseAccessor<AppDatabase> with _$ProductsDaoMixin {
  ProductsDao(super.db);

  // Categories
  Future<List<Category>> getAllCategories() =>
      select(db.categories).get();

  Stream<List<Category>> watchAllCategories() =>
      select(db.categories).watch();

  Future<String> insertCategory(CategoriesCompanion data) =>
      into(db.categories).insertReturning(data).then((c) => c.id);

  Future<void> updateCategory(CategoriesCompanion data) =>
      update(db.categories).replace(data);

  Future<void> deleteCategory(String id) =>
      (delete(db.categories)..where((t) => t.id.equals(id))).go();

  Future<int> getProductCountByCategory(String categoryId) async {
    final result = await (selectOnly(db.products)
      ..addColumns([db.products.id.count()])
      ..where(db.products.categoryId.equals(categoryId) & db.products.isActive.equals(true))
    ).getSingle();
    return result.read(db.products.id.count()) ?? 0;
  }

  // Products
  Future<List<Product>> getAllProducts() =>
      (select(db.products)..where((p) => p.isActive.equals(true))).get();

  Stream<List<Product>> watchAllProducts() {
    return (select(db.products)..where((p) => p.isActive.equals(true)))
      .watch()
      .map((products) {
        products.sort((a, b) {
          // Out of stock products go to bottom
          if (a.stockQty <= 0 && b.stockQty > 0) return 1;
          if (a.stockQty > 0 && b.stockQty <= 0) return -1;
          // Both in stock or both out of stock, sort by updatedAt descending
          return b.updatedAt.compareTo(a.updatedAt);
        });
        return products;
      });
  }

  Stream<List<Product>> watchLowStockProducts() {
    return customSelect(
      'SELECT * FROM products WHERE is_active = 1 AND stock_qty <= low_stock_threshold',
      readsFrom: {db.products},
    ).watch().map((rows) => rows.map((row) => db.products.map(row.data)).toList());
  }

  Future<Product?> getProductById(String id) =>
      (select(db.products)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<Product>> searchProducts(String query) =>
      (select(db.products)
        ..where((p) => p.isActive.equals(true) & p.name.contains(query)))
      .get();

  Future<String> insertProduct(ProductsCompanion data) =>
      into(db.products).insertReturning(data).then((p) => p.id);

  Future<void> updateProduct(ProductsCompanion data) {
    final updatedData = data.copyWith(
      updatedAt: Value(DateTime.now()),
      createdAt: const Value.absent(),
    );
    return (update(db.products)..where((p) => p.id.equals(data.id.value))).write(updatedData);
  }

  Future<void> updateStock(String productId, int newQty) =>
      (update(db.products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(stockQty: Value(newQty)));

  Future<void> softDeleteProduct(String id) =>
      (update(db.products)..where((p) => p.id.equals(id)))
        .write(const ProductsCompanion(isActive: Value(false)));
}