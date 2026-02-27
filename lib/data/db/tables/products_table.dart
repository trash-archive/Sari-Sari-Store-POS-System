import 'package:drift/drift.dart';
import 'categories_table.dart';

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get description => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pc'))();
  TextColumn get barcode => text().nullable()();
  IntColumn get priceCents => integer().withDefault(const Constant(0))();
  IntColumn get costCents => integer().nullable()();
  IntColumn get stockQty => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}