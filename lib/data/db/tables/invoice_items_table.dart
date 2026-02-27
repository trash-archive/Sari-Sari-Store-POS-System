import 'package:drift/drift.dart';
import 'invoices_table.dart';

class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(Invoices, #id)();
  TextColumn get productId => text()();
  TextColumn get productNameSnapshot => text()();
  TextColumn get unitSnapshot => text()();
  IntColumn get priceSnapshotCents => integer()();
  IntColumn get qty => integer()();
  IntColumn get lineTotalCents => integer()();

  @override
  Set<Column> get primaryKey => {id};
}