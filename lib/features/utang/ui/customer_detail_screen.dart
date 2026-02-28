import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/services/pdf_service.dart';
import '../state/customers_provider.dart';
import '../../invoices/ui/invoice_detail_screen.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  Customer? _current;

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customer.id));
    final customer = customerAsync.valueOrNull ?? _current ?? widget.customer;
    _current = customer;

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export Statement PDF',
            onPressed: () => _exportStatement(context, customer),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _editCustomer(context, customer);
              if (v == 'delete') _deleteCustomer(context, customer);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Customer')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete Customer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance header
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: customer.balanceCents > 0
                    ? [Colors.red[700]!, Colors.red[400]!]
                    : [Colors.green[700]!, Colors.green[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      radius: 26,
                      child: Text(customer.name[0].toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        if (customer.phone != null)
                          Text(customer.phone!,
                              style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Balance',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  formatCurrency(customer.balanceCents),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                if (customer.balanceCents > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red[700],
                        ),
                        onPressed: () => _recordPayment(context, customer),
                        icon: const Icon(Icons.payment),
                        label: const Text('Record Payment'),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Ledger title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Text('Transaction History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Text('Sorted newest first',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          const Divider(),

          // Ledger
          Expanded(child: _LedgerList(customerId: customer.id)),
        ],
      ),
    );
  }

  void _recordPayment(BuildContext context, Customer customer) {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment from ${customer.name}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Balance',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatCurrency(customer.balanceCents),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: amountCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (₱)',
                    prefixText: '₱',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Amount is required';
                    final amount = double.tryParse(v!);
                    if (amount == null || amount <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final raw = double.parse(amountCtrl.text);
                        final amountCents = (raw * 100).round();
                        await ref.read(customersNotifierProvider.notifier).recordPayment(
                          customerId: customer.id,
                          amountCents: amountCents,
                          notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(customerDetailProvider(customer.id));
                      },
                      child: const Text('Record Payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editCustomer(BuildContext context, Customer customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone ?? '');
    final addressCtrl = TextEditingController(text: customer.address ?? '');
    final notesCtrl = TextEditingController(text: customer.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 8),
              TextField(
                  controller: phoneCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 8),
              TextField(
                  controller: addressCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ref
                  .read(customersNotifierProvider.notifier)
                  .updateCustomerFields(
                    customer: customer,
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                    address: addressCtrl.text.isEmpty ? null : addressCtrl.text.trim(),
                    notes: notesCtrl.text.isEmpty ? null : notesCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              ref.invalidate(customerDetailProvider(customer.id));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(customersNotifierProvider.notifier).deleteCustomer(customer.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportStatement(BuildContext context, Customer customer) async {
    try {
      final db = ref.read(databaseProvider);
      final invoices = await db.invoicesDao.getUtangInvoicesForCustomer(customer.id);
      final payments = await db.customersDao.getPaymentsForCustomer(customer.id);

      final ledger = <_LedgerEntry>[];
      for (final inv in invoices) {
        ledger.add(_LedgerEntry(
          date: inv.createdAt,
          type: 'utang',
          description: inv.invoiceNo,
          amountCents: inv.totalCents,
        ));
      }
      for (final pay in payments) {
        ledger.add(_LedgerEntry(
          date: pay.createdAt,
          type: 'payment',
          description: pay.notes ?? 'Payment',
          amountCents: pay.amountCents,
        ));
      }
      ledger.sort((a, b) => a.date.compareTo(b.date));

      final storeName = ref.read(settingsProvider).storeName;
      await PdfService.printCustomerStatement(
        customer: customer,
        ledger: ledger
            .map((e) => PdfLedgerEntry(
                  date: e.date,
                  type: e.type,
                  description: e.description,
                  amountCents: e.amountCents,
                ))
            .toList(),
        storeName: storeName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('PDF error: $e'),
                backgroundColor: Colors.red));
      }
    }
  }
}

class _LedgerEntry {
  final DateTime date;
  final String type;
  final String description;
  final int amountCents;
  _LedgerEntry(
      {required this.date,
      required this.type,
      required this.description,
      required this.amountCents});
}

// ─── Ledger List Widget ──────────────────────────────────────────────────────

class _LedgerList extends ConsumerWidget {
  final String customerId;
  const _LedgerList({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(customerUtangInvoicesProvider(customerId));
    final paymentsAsync = ref.watch(customerPaymentsProvider(customerId));

    if (invoicesAsync.isLoading || paymentsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final invoices = invoicesAsync.valueOrNull ?? [];
    final payments = paymentsAsync.valueOrNull ?? [];

    if (invoices.isEmpty && payments.isEmpty) {
      return const Center(
        child: Text('No transactions yet',
            style: TextStyle(color: Colors.grey)),
      );
    }

    // Build combined ledger entries
    final entries = <_LedgerEntry>[];
    for (final inv in invoices) {
      entries.add(_LedgerEntry(
        date: inv.createdAt,
        type: 'utang',
        description: inv.invoiceNo,
        amountCents: inv.totalCents,
      ));
    }
    for (final pay in payments) {
      entries.add(_LedgerEntry(
        date: pay.createdAt,
        type: 'payment',
        description: pay.notes ?? 'Payment',
        amountCents: pay.amountCents,
      ));
    }
    entries.sort((a, b) => b.date.compareTo(a.date)); // newest first

    // Compute running balances (from oldest to newest, then reverse display)
    int balance = 0;
    final balances = <int>[];
    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      if (e.type == 'utang') {
        balance += e.amountCents;
      } else {
        balance = (balance - e.amountCents).clamp(0, 999999999);
      }
      balances.add(balance);
    }
    // Map date -> balance from oldest to newest
    final balanceMap = <String, int>{};
    for (int i = 0; i < sorted.length; i++) {
      balanceMap[sorted[i].date.toIso8601String() + sorted[i].description] =
          balances[i];
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final runningBal = balanceMap[
                entry.date.toIso8601String() + entry.description] ??
            0;
        final isPayment = entry.type == 'payment';
        final isInvoice = entry.type == 'utang';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isPayment ? Colors.green[100] : Colors.red[100],
              child: Icon(
                isPayment ? Icons.arrow_downward : Icons.arrow_upward,
                color: isPayment ? Colors.green[700] : Colors.red[700],
                size: 20,
              ),
            ),
            title: Text(
              entry.description,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(formatDateTime(entry.date),
                style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPayment ? '−' : '+'}${formatCurrency(entry.amountCents)}',
                  style: TextStyle(
                    color: isPayment ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Bal: ${formatCurrency(runningBal)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            onTap: isInvoice
                ? () {
                    // Find invoice by invoiceNo
                    final inv = (invoicesAsync.valueOrNull ?? [])
                        .where((inv) => inv.invoiceNo == entry.description)
                        .firstOrNull;
                    if (inv != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                InvoiceDetailScreen(invoiceId: inv.id)),
                      );
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}