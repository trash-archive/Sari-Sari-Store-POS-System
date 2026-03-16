import 'package:drift/drift.dart';
import 'customers_table.dart';
import 'invoices_table.dart';

class CustomerPayments extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text().references(Customers, #id)();
  TextColumn get invoiceId => text().nullable().references(Invoices, #id)();
  IntColumn get amountCents => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get syncId => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}