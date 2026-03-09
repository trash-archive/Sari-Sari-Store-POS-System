import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../data/db/app_database.dart';
import '../../settings/ui/settings_screen.dart';
import 'invoice_detail_screen.dart';

class TransactionItem {
  final String id;
  final String type; // 'invoice' or 'payment'
  final DateTime date;
  final int amountCents;
  final String? invoiceNo;
  final String? invoiceType;
  final String? status;
  final String? customerName;
  
  TransactionItem({
    required this.id,
    required this.type,
    required this.date,
    required this.amountCents,
    this.invoiceNo,
    this.invoiceType,
    this.status,
    this.customerName,
  });
}

final transactionHistoryProvider = StreamProvider<List<TransactionItem>>((ref) async* {
  final db = ref.watch(databaseProvider);
  
  await for (final _ in db.select(db.invoices).watch()) {
    final invoices = await db.select(db.invoices).get();
    final customers = await db.select(db.customers).get();
    final customerMap = {for (var c in customers) c.id: c.name};
    
    final transactions = <TransactionItem>[
      ...invoices.map((inv) => TransactionItem(
        id: inv.id,
        type: inv.type == 'payment' ? 'payment' : 'invoice',
        date: inv.createdAt,
        amountCents: inv.totalCents,
        invoiceNo: inv.invoiceNo,
        invoiceType: inv.type,
        status: inv.status,
        customerName: inv.customerId != null ? customerMap[inv.customerId] : null,
      )),
    ];
    
    transactions.sort((a, b) => b.date.compareTo(a.date));
    yield transactions;
  }
});

class InvoiceHistoryScreen extends ConsumerStatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  ConsumerState<InvoiceHistoryScreen> createState() =>
      _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends ConsumerState<InvoiceHistoryScreen> {
  String _filter = 'all'; // all | cash | utang | payment | voided
  String _dateFilter = 'all'; // all | today | week | month

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionHistoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Invoice History', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(label: 'All', value: 'all', current: _filter,
                            onTap: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Cash', value: 'cash', current: _filter,
                            onTap: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Utang', value: 'utang', current: _filter,
                            onTap: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Payments', value: 'payment', current: _filter,
                            onTap: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Voided', value: 'voided', current: _filter,
                            onTap: (v) => setState(() => _filter = v)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _dateFilter != 'all' ? AppTheme.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _dateFilter != 'all' ? AppTheme.primary : Colors.grey.shade300),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      color: _dateFilter != 'all' ? Colors.white : Colors.grey.shade600,
                      size: 20,
                    ),
                    tooltip: 'Date Filter',
                    onPressed: () => _showDateFilter(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (transactions) {
                // Apply filters
                var filtered = transactions.where((txn) {
                  // Type filter
                  if (_filter == 'all') {
                    // Show everything including voided
                  } else if (_filter == 'payment') {
                    if (txn.invoiceType != 'payment') return false;
                  } else if (_filter == 'voided') {
                    if (txn.status != 'voided') return false;
                  } else {
                    if (txn.invoiceType != _filter || txn.status == 'voided') return false;
                  }
                  
                  // Date filter
                  final now = DateTime.now();
                  if (_dateFilter == 'today') {
                    final today = DateTime(now.year, now.month, now.day);
                    if (txn.date.isBefore(today)) return false;
                  } else if (_dateFilter == 'week') {
                    final weekAgo = now.subtract(const Duration(days: 7));
                    if (txn.date.isBefore(weekAgo)) return false;
                  } else if (_dateFilter == 'month') {
                    final monthStart = DateTime(now.year, now.month, 1);
                    if (txn.date.isBefore(monthStart)) return false;
                  }
                  
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions found',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final txn = filtered[i];
                    return _TransactionTile(
                      transaction: txn,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => InvoiceDetailScreen(invoiceId: txn.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDateFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('Date Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildDateOption(ctx, 'All Time', 'all', Icons.calendar_today),
              _buildDateOption(ctx, 'Today', 'today', Icons.today),
              _buildDateOption(ctx, 'Last 7 Days', 'week', Icons.date_range),
              _buildDateOption(ctx, 'This Month', 'month', Icons.calendar_month),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDateOption(BuildContext ctx, String label, String value, IconData icon) {
    final isSelected = _dateFilter == value;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? AppTheme.primary : Colors.grey.shade600,
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      selected: isSelected,
      selectedTileColor: AppTheme.primary.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        setState(() => _dateFilter = value);
        Navigator.pop(ctx);
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;
  const _FilterChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.grey.shade300,
              width: 1,
            ),
            boxShadow: selected ? [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final TransactionItem transaction;
  final VoidCallback? onTap;
  const _TransactionTile({required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPayment = transaction.invoiceType == 'payment';
    final isVoided = transaction.status == 'voided';
    final isUtang = transaction.invoiceType == 'utang';

    IconData icon;
    Color bgColor;
    Color iconColor;
    
    if (isVoided) {
      icon = Icons.block;
      bgColor = Colors.red.shade50;
      iconColor = Colors.red.shade700;
    } else if (isPayment) {
      icon = Icons.account_balance_wallet;
      bgColor = Colors.blue.shade50;
      iconColor = Colors.blue.shade700;
    } else if (isUtang) {
      icon = Icons.credit_card;
      bgColor = Colors.orange.shade50;
      iconColor = Colors.orange.shade700;
    } else {
      icon = Icons.payments;
      bgColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.invoiceNo!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isVoided ? Colors.grey.shade600 : AppTheme.textPrimary,
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (transaction.customerName != null)
                        Text(
                          transaction.customerName!,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        formatDateTime(transaction.date),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${isPayment ? '+' : ''}${formatCurrency(transaction.amountCents)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isVoided ? Colors.grey.shade600 : isPayment ? Colors.green.shade700 : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}