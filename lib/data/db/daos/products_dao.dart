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

  // Products
  Future<List<Product>> getAllProducts() =>
      (select(db.products)..where((p) => p.isActive.equals(true))).get();

  Stream<List<Product>> watchAllProducts() =>
      (select(db.products)..where((p) => p.isActive.equals(true))
        ..orderBy([(p) => OrderingTerm.asc(p.name)])).watch();

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

  Future<void> updateProduct(ProductsCompanion data) =>
      update(db.products).replace(data);

  Future<void> updateStock(String productId, int newQty) =>
      (update(db.products)..where((p) => p.id.equals(productId)))
        .write(ProductsCompanion(stockQty: Value(newQty)));

  Future<void> softDeleteProduct(String id) =>
      (update(db.products)..where((p) => p.id.equals(id)))
        .write(const ProductsCompanion(isActive: Value(false)));
}