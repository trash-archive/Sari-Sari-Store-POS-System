import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';

const _uuid = Uuid();

// Categories
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.productsDao.watchAllCategories();
});

final categoryProductCountProvider = FutureProvider.family<int, String>((ref, categoryId) async {
  final db = ref.watch(databaseProvider);
  return db.productsDao.getProductCountByCategory(categoryId);
});

// Products
final productsProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.productsDao.watchAllProducts();
});

final lowStockProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.productsDao.watchLowStockProducts();
});

final productSearchProvider = FutureProvider.family<List<Product>, String>((ref, query) async {
  if (query.isEmpty) return ref.watch(productsProvider).value ?? [];
  final db = ref.watch(databaseProvider);
  return db.productsDao.searchProducts(query);
});

// Actions
class ProductsNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<void> addProduct({
    required String name,
    required String categoryId,
    required int priceCents,
    required String unit,
    int? costCents,
    String? description,
    String? barcode,
    int stockQty = 0,
    int lowStockThreshold = 5,
    String? imagePath,
  }) async {
    final id = _uuid.v4();
    await _db.productsDao.insertProduct(ProductsCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: Value(categoryId),
      priceCents: Value(priceCents),
      unit: Value(unit),
      costCents: Value(costCents),
      description: Value(description),
      barcode: Value(barcode),
      stockQty: Value(stockQty),
      lowStockThreshold: Value(lowStockThreshold),
      imagePath: Value(imagePath),
    ));
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String categoryId,
    required int priceCents,
    required String unit,
    int? costCents,
    String? description,
    String? barcode,
    int? stockQty,
    int? lowStockThreshold,
    String? imagePath,
  }) async {
    final product = await _db.productsDao.getProductById(id);
    if (product == null) return;
    
    await _db.productsDao.updateProduct(ProductsCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: Value(categoryId),
      priceCents: Value(priceCents),
      unit: Value(unit),
      costCents: Value(costCents),
      description: Value(description),
      barcode: Value(barcode),
      stockQty: Value(stockQty ?? product.stockQty),
      lowStockThreshold: Value(lowStockThreshold ?? product.lowStockThreshold),
      imagePath: Value(imagePath),
      isActive: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> adjustStock(String productId, int currentStock, int changeQty, String reason, String? notes) async {
    final newQty = (currentStock + changeQty).clamp(0, 999999);
    await _db.productsDao.updateStock(productId, newQty);
    await _db.into(_db.stockMovements).insert(StockMovementsCompanion(
      id: Value(_uuid.v4()),
      productId: Value(productId),
      changeQty: Value(changeQty),
      reason: Value(reason),
      notes: Value(notes),
    ));
  }

  Future<void> addCategory(String name) async {
    await _db.productsDao.insertCategory(CategoriesCompanion(
      id: Value(_uuid.v4()),
      name: Value(name),
    ));
  }

  Future<void> updateCategory(String id, String name) async {
    await _db.productsDao.updateCategory(CategoriesCompanion(
      id: Value(id),
      name: Value(name),
    ));
  }

  Future<void> deleteCategory(String id) async {
    final productCount = await _db.productsDao.getProductCountByCategory(id);
    if (productCount > 0) {
      throw Exception('Cannot delete category with $productCount product${productCount > 1 ? 's' : ''}');
    }
    await _db.productsDao.deleteCategory(id);
  }

  Future<void> deleteProduct(String id) async {
    await _db.productsDao.softDeleteProduct(id);
  }
}

final productsNotifierProvider = NotifierProvider<ProductsNotifier, void>(ProductsNotifier.new);

// Stock movements for a product
final stockMovementsProvider = StreamProvider.family<List<StockMovement>, String>((ref, productId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.stockMovements)
    ..where((t) => t.productId.equals(productId))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
  .watch();
});