import 'package:drift/drift.dart';
import 'customers_table.dart';

class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNo => text().unique()();
  TextColumn get type => text()(); // 'cash' | 'utang'
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active' | 'voided'
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  IntColumn get subtotalCents => integer().withDefault(const Constant(0))();
  IntColumn get discountCents => integer().withDefault(const Constant(0))();
  IntColumn get totalCents => integer().withDefault(const Constant(0))();
  IntColumn get cashReceivedCents => integer().nullable()();
  IntColumn get changeCents => integer().nullable()();
  IntColumn get balanceBeforeCents => integer().nullable()();
  IntColumn get balanceAfterCents => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}