import 'package:drift/drift.dart';
import '../app_database.dart';

part 'customers_dao.g.dart';

@DriftAccessor(tables: [Customers, CustomerPayments])
class CustomersDao extends DatabaseAccessor<AppDatabase> with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Stream<List<Customer>> watchAllCustomers() =>
      (select(db.customers)
        ..orderBy([(c) => OrderingTerm.desc(c.balanceCents)])).watch();

  Future<List<Customer>> searchCustomers(String query) =>
      (select(db.customers)..where((c) => c.name.contains(query))).get();

  Future<Customer?> getCustomerById(String id) =>
      (select(db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<String> insertCustomer(CustomersCompanion data) =>
      into(db.customers).insertReturning(data).then((c) => c.id);

  Future<void> updateCustomer(CustomersCompanion data) =>
      update(db.customers).replace(data);

  Future<List<CustomerPayment>> getPaymentsForCustomer(String customerId) =>
      (select(db.customerPayments)
        ..where((p) => p.customerId.equals(customerId))
        ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();

  Future<void> recordPayment({
    required CustomerPaymentsCompanion paymentData,
    required String customerId,
    required int amountCents,
    String? invoiceId,
  }) async {
    await db.transaction(() async {
      await into(db.customerPayments).insert(paymentData);
      final customer = await getCustomerById(customerId);
      if (customer != null) {
        final newBalance = (customer.balanceCents - amountCents).clamp(0, 999999999);
        await (update(db.customers)..where((c) => c.id.equals(customerId)))
          .write(CustomersCompanion(
            balanceCents: Value(newBalance),
            updatedAt: Value(DateTime.now()),
          ));
      }
    });
  }
}