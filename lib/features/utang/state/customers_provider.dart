import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';

const _uuid = Uuid();

final customersProvider = StreamProvider<List<Customer>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.customersDao.watchAllCustomers();
});

final customerDetailProvider = StreamProvider.family<Customer?, String>((ref, id) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.customers)..where((c) => c.id.equals(id))).watchSingleOrNull();
});

final customerPaymentsProvider = StreamProvider.family<List<CustomerPayment>, String>((ref, customerId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.customerPayments)
    ..where((p) => p.customerId.equals(customerId))
    ..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();
});

final customerUtangInvoicesProvider = StreamProvider.family<List<Invoice>, String>((ref, customerId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.invoices)
    ..where((i) => i.customerId.equals(customerId) & i.type.equals('utang'))
    ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).watch();
});

class CustomersNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<String> addCustomer({required String name, String? phone, String? address, String? notes}) async {
    final id = _uuid.v4();
    await _db.customersDao.insertCustomer(CustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      address: Value(address),
      notes: Value(notes),
    ));
    return id;
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db.customersDao.updateCustomer(CustomersCompanion(
      id: Value(customer.id),
      name: Value(customer.name),
      phone: Value(customer.phone),
      address: Value(customer.address),
      notes: Value(customer.notes),
      balanceCents: Value(customer.balanceCents),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> recordPayment({required String customerId, required int amountCents, String? notes}) async {
    await _db.customersDao.recordPayment(
      paymentData: CustomerPaymentsCompanion(
        id: Value(_uuid.v4()),
        customerId: Value(customerId),
        amountCents: Value(amountCents),
        notes: Value(notes),
        createdAt: Value(DateTime.now()),
      ),
      customerId: customerId,
      amountCents: amountCents,
    );
  }

  Future<void> updateCustomerFields({
    required Customer customer,
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    await _db.customersDao.updateCustomer(CustomersCompanion(
      id: Value(customer.id),
      name: Value(name),
      phone: Value(phone),
      address: Value(address),
      notes: Value(notes),
      balanceCents: Value(customer.balanceCents),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteCustomer(String customerId) async {
    await (_db.delete(_db.customers)..where((c) => c.id.equals(customerId))).go();
  }
}

final customersNotifierProvider = NotifierProvider<CustomersNotifier, void>(CustomersNotifier.new);