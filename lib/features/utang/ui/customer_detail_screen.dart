import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
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
  bool _isReversed = false;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailProvider(widget.customer.id));
    final customer = customerAsync.valueOrNull ?? _current ?? widget.customer;
    _current = customer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8F5E9), Color(0xFFF1F8F4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatCurrency(customer.balanceCents),
                            style: const TextStyle(
                              color: Color(0xFF2D5F3F),
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (customer.balanceCents > 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D5F3F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _recordPayment(context, customer),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Transaction history header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showDateFilter(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _dateRange != null ? const Color(0xFF2D5F3F) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _dateRange != null ? const Color(0xFF2D5F3F) : Colors.grey.shade300),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: _dateRange != null ? Colors.white : const Color(0xFF2D5F3F),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isReversed = !_isReversed;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_vert,
                          size: 14,
                          color: Color(0xFF2D5F3F),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isReversed ? 'Oldest' : 'Newest',
                          style: const TextStyle(
                            color: Color(0xFF2D5F3F),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ledger
          Expanded(child: _LedgerList(customerId: customer.id, isReversed: _isReversed, dateRange: _dateRange)),
        ],
      ),
    );
  }

  void _recordPayment(BuildContext context, Customer customer) {
    final amountPaidCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    double? changeDue;
    String? photoPath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxHeight: 600),
            child: SingleChildScrollView(
              child: Padding(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                              'Outstanding Balance',
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
                        controller: amountPaidCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Amount Paid (₱)',
                          prefixText: '₱',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (value) {
                          final paid = double.tryParse(value) ?? 0;
                          final balance = customer.balanceCents / 100;
                          setState(() {
                            changeDue = paid > balance ? paid - balance : null;
                          });
                        },
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) return 'Amount is required';
                          final amount = double.tryParse(v!);
                          if (amount == null || amount <= 0) return 'Enter valid amount';
                          return null;
                        },
                      ),
                      if (changeDue != null && changeDue! > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Due',
                                style: TextStyle(fontSize: 12, color: Colors.green[700]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCurrency((changeDue! * 100).round()),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (ref.read(settingsProvider).enableTransactionPhotos) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final imgService = ref.read(imageStorageProvider);
                            final path = await imgService.captureTransactionPhoto();
                            setState(() => photoPath = path);
                          },
                          icon: Icon(photoPath != null ? Icons.check_circle : Icons.camera_alt),
                          label: Text(photoPath != null ? 'Photo captured' : 'Capture photo (optional)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: photoPath != null ? Colors.green : null,
                          ),
                        ),
                      ],
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
                              final amountPaid = double.parse(amountPaidCtrl.text);
                              final amountPaidCents = (amountPaid * 100).round();
                              
                              final invoiceId = await ref.read(customersNotifierProvider.notifier).recordPayment(
                                customerId: customer.id,
                                amountCents: amountPaidCents,
                                notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                                cashReceivedCents: amountPaidCents,
                                photoPath: photoPath,
                              );
                              
                              if (ctx.mounted) Navigator.pop(ctx);
                              ref.invalidate(customerDetailProvider(customer.id));
                              
                              if (context.mounted) {
                                final actualPayment = amountPaidCents > customer.balanceCents ? customer.balanceCents : amountPaidCents;
                                final change = amountPaidCents > actualPayment ? amountPaidCents - actualPayment : 0;
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Payment recorded: ${formatCurrency(actualPayment)}${change > 0 ? '\nChange: ${formatCurrency(change)}' : ''}',
                                    ),
                                    backgroundColor: const Color(0xFF2E7D32),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                    action: SnackBarAction(
                                      label: 'View',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
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
          ),
        ),
      ),
    );
  }

  void _editCustomer(BuildContext context, Customer customer) async {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone ?? '');
    final addressCtrl = TextEditingController(text: customer.address ?? '');
    final notesCtrl = TextEditingController(text: customer.notes ?? '');
    final formKey = GlobalKey<FormState>();
    
    // Fetch all customers for duplicate validation
    final allCustomers = await ref.read(databaseProvider).customersDao.searchCustomers('');

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      const Text('Edit Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Customer Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                            const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            hintText: 'Enter customer name',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            errorMaxLines: 2,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'Customer name is required';
                            if (v!.trim().length > 30) return 'Name must be 30 characters or less';
                            final exists = allCustomers.any((c) => c.name.toLowerCase() == v.trim().toLowerCase() && c.id != customer.id);
                            if (exists) return 'Customer with this name already exists';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Phone (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: InputDecoration(
                            hintText: 'Enter phone number',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(15),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Address (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addressCtrl,
                          decoration: InputDecoration(
                            hintText: 'Enter address',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Notes (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: notesCtrl,
                          decoration: InputDecoration(
                            hintText: 'Enter notes',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (formKey.currentState!.validate()) {
                                    try {
                                      await ref.read(customersNotifierProvider.notifier).updateCustomerFields(
                                        customer: customer,
                                        name: nameCtrl.text.trim(),
                                        phone: phoneCtrl.text.isEmpty ? null : phoneCtrl.text.trim(),
                                        address: addressCtrl.text.isEmpty ? null : addressCtrl.text.trim(),
                                        notes: notesCtrl.text.isEmpty ? null : notesCtrl.text.trim(),
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      ref.invalidate(customerDetailProvider(customer.id));
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString().replaceAll('Exception: ', '')),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDateFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Filter by Date',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_dateRange != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _dateRange = null);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildDateOption(ctx, 'Today', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(start: now, end: now));
              Navigator.pop(ctx);
            }),
            _buildDateOption(ctx, 'Last 7 Days', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(
                start: now.subtract(const Duration(days: 6)),
                end: now,
              ));
              Navigator.pop(ctx);
            }),
            _buildDateOption(ctx, 'Last 30 Days', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(
                start: now.subtract(const Duration(days: 29)),
                end: now,
              ));
              Navigator.pop(ctx);
            }),
            _buildDateOption(ctx, 'This Month', () {
              final now = DateTime.now();
              setState(() => _dateRange = DateTimeRange(
                start: DateTime(now.year, now.month, 1),
                end: now,
              ));
              Navigator.pop(ctx);
            }),
            const Divider(height: 24),
            _buildDateOption(ctx, 'Custom Range', () async {
              Navigator.pop(ctx);
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _dateRange,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF2D5F3F),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (range != null) {
                setState(() => _dateRange = range);
              }
            }, icon: Icons.date_range),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDateOption(BuildContext ctx, String label, VoidCallback onTap, {IconData? icon}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon ?? Icons.calendar_today_outlined,
              size: 20,
              color: const Color(0xFF2D5F3F),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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
      final invoices = await db.invoicesDao.getAllInvoicesForCustomer(customer.id);
      final payments = await db.customersDao.getPaymentsForCustomer(customer.id);

      final ledger = <_LedgerEntry>[];
      for (final inv in invoices) {
        int displayAmount = inv.totalCents;
        String entryType = inv.type == 'cash' ? 'partial_payment' : inv.type;
        
        // For partial payments, show the utang amount (what was added to customer balance)
        if (inv.type == 'cash' && inv.customerId != null && inv.cashReceivedCents != null) {
          displayAmount = inv.totalCents - inv.cashReceivedCents!;
        }
        
        ledger.add(_LedgerEntry(
          date: inv.createdAt,
          type: entryType,
          description: inv.invoiceNo,
          amountCents: displayAmount,
          isVoided: inv.status == 'voided',
        ));
      }
      for (final pay in payments) {
        ledger.add(_LedgerEntry(
          date: pay.createdAt,
          type: 'payment',
          description: pay.notes ?? 'Payment',
          amountCents: pay.amountCents,
          isVoided: false,
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
  final bool isVoided;
  _LedgerEntry(
      {required this.date,
      required this.type,
      required this.description,
      required this.amountCents,
      this.isVoided = false});
}

// ─── Ledger List Widget ──────────────────────────────────────────────────────

class _LedgerList extends ConsumerWidget {
  final String customerId;
  final bool isReversed;
  final DateTimeRange? dateRange;
  const _LedgerList({required this.customerId, required this.isReversed, this.dateRange});

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
      int displayAmount = inv.totalCents;
      String entryType = inv.type == 'cash' ? 'partial_payment' : inv.type;
      
      // For partial payments, show the utang amount (what was added to customer balance)
      if (inv.type == 'cash' && inv.customerId != null && inv.cashReceivedCents != null) {
        displayAmount = inv.totalCents - inv.cashReceivedCents!;
      }
      
      entries.add(_LedgerEntry(
        date: inv.createdAt,
        type: entryType,
        description: inv.invoiceNo,
        amountCents: displayAmount,
        isVoided: inv.status == 'voided',
      ));
    }
    for (final pay in payments) {
      // Check if the payment's associated invoice is voided
      final associatedInvoice = pay.invoiceId != null 
          ? invoices.where((inv) => inv.id == pay.invoiceId).firstOrNull
          : null;
      entries.add(_LedgerEntry(
        date: pay.createdAt,
        type: 'payment',
        description: pay.notes ?? 'Payment',
        amountCents: pay.amountCents,
        isVoided: associatedInvoice?.status == 'voided',
      ));
    }
    
    // Apply date filter
    final filtered = dateRange == null
        ? entries
        : entries.where((e) {
            final date = DateTime(e.date.year, e.date.month, e.date.day);
            final start = DateTime(dateRange!.start.year, dateRange!.start.month, dateRange!.start.day);
            final end = DateTime(dateRange!.end.year, dateRange!.end.month, dateRange!.end.day);
            return !date.isBefore(start) && !date.isAfter(end);
          }).toList();
    
    filtered.sort((a, b) => isReversed ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No transactions in selected date range',
            style: TextStyle(color: Colors.grey)),
      );
    }

    // Compute running balances (from oldest to newest, then reverse display)
    int balance = 0;
    final balances = <int>[];
    final sorted = [...filtered]..sort((a, b) => a.date.compareTo(b.date));
    for (final e in sorted) {
      if (e.type == 'utang') {
        balance += e.amountCents;
      } else if (e.type == 'partial_payment') {
        // For partial payments, only the remaining balance (after cash received) is added to utang
        // The invoice total already represents what was added to customer balance
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
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final entry = filtered[i];
        final runningBal = balanceMap[
                entry.date.toIso8601String() + entry.description] ??
            0;
        final isPayment = entry.type == 'payment';
        final isInvoice = entry.type == 'utang';
        final isPartialPayment = entry.type == 'partial_payment';
        final isVoided = entry.isVoided;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isVoided ? Colors.red.shade50 : 
                  (isPayment ? Colors.blue.shade50 : 
                   isPartialPayment ? Colors.purple.shade50 : Colors.orange.shade50),
              child: Icon(
                isVoided ? Icons.block : 
                (isPayment ? Icons.account_balance_wallet : 
                 isPartialPayment ? Icons.payment : Icons.credit_card),
                color: isVoided ? Colors.red.shade700 : 
                      (isPayment ? Colors.blue.shade700 : 
                       isPartialPayment ? Colors.purple.shade700 : Colors.orange.shade700),
                size: 20,
              ),
            ),
            title: Text(
              entry.description,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isVoided ? Colors.grey.shade600 : AppTheme.textPrimary,
                decoration: isVoided ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(formatDateTime(entry.date),
                style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(isPayment) ? '−' : '+'}${formatCurrency(entry.amountCents)}',
                  style: TextStyle(
                    color: isVoided ? Colors.grey.shade600 : 
                           (isPayment ? Colors.green[700] : 
                            isPartialPayment ? Colors.purple[700] : Colors.red[700]),
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
            onTap: () {
              if (isInvoice || isPartialPayment) {
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
              } else if (isPayment) {
                final payment = (paymentsAsync.valueOrNull ?? [])
                    .where((p) => (p.notes ?? 'Payment') == entry.description && p.createdAt == entry.date)
                    .firstOrNull;
                if (payment?.invoiceId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            InvoiceDetailScreen(invoiceId: payment!.invoiceId!)),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
}