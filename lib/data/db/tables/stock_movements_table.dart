import 'package:drift/drift.dart';
import 'products_table.dart';

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get changeQty => integer()();
  TextColumn get reason => text()(); // sale | restock | adjustment | void
  TextColumn get referenceId => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}