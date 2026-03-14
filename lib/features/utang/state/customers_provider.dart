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
    ..where((i) => 
      i.customerId.equals(customerId) & 
      (i.type.equals('utang') | i.type.equals('cash')) &
      i.status.equals('active'))
    ..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).watch();
});

class CustomersNotifier extends Notifier<void> {
  @override
  void build() {}

  AppDatabase get _db => ref.read(databaseProvider);

  Future<String> addCustomer({required String name, String? phone, String? address, String? notes}) async {
    // Check for duplicate customer name
    final existing = await _db.customersDao.searchCustomers(name);
    if (existing.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('Customer with this name already exists');
    }
    
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

  Future<String> recordPayment({
    required String customerId,
    required int amountCents,
    String? notes,
    int? cashReceivedCents,
    String? photoPath,
  }) async {
    final paymentId = _uuid.v4();
    final invoiceId = _uuid.v4();
    final invoiceNo = 'PAY-${await _db.invoicesDao.getNextInvoiceNumber()}';
    final now = DateTime.now();
    
    final customer = await _db.customersDao.getCustomerById(customerId);
    if (customer == null) throw Exception('Customer not found');
    
    final actualPayment = amountCents > customer.balanceCents ? customer.balanceCents : amountCents;
    final changeCents = cashReceivedCents != null && cashReceivedCents > actualPayment
        ? cashReceivedCents - actualPayment
        : null;
    final balanceBeforeCents = customer.balanceCents;
    final balanceAfterCents = customer.balanceCents - actualPayment;

    await _db.transaction(() async {
      await _db.into(_db.invoices).insert(InvoicesCompanion(
        id: Value(invoiceId),
        invoiceNo: Value(invoiceNo),
        type: const Value('payment'),
        customerId: Value(customerId),
        subtotalCents: Value(actualPayment),
        discountCents: const Value(0),
        totalCents: Value(actualPayment),
        cashReceivedCents: Value(cashReceivedCents),
        changeCents: Value(changeCents),
        balanceBeforeCents: Value(balanceBeforeCents),
        balanceAfterCents: Value(balanceAfterCents),
        notes: Value(notes),
        photoPath: Value(photoPath),
        createdAt: Value(now),
      ));

      await _db.customersDao.recordPayment(
        paymentData: CustomerPaymentsCompanion(
          id: Value(paymentId),
          customerId: Value(customerId),
          invoiceId: Value(invoiceId),
          amountCents: Value(actualPayment),
          notes: Value(notes),
          createdAt: Value(now),
        ),
        customerId: customerId,
        amountCents: actualPayment,
        invoiceId: invoiceId,
      );
    });
    
    return invoiceId;
  }

  Future<void> updateCustomerFields({
    required Customer customer,
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    // Check for duplicate customer name (excluding current customer)
    final existing = await _db.customersDao.searchCustomers(name);
    if (existing.any((c) => c.name.toLowerCase() == name.toLowerCase() && c.id != customer.id)) {
      throw Exception('Customer with this name already exists');
    }
    
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