import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import 'invoice_detail_screen.dart';

final invoiceHistoryProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(databaseProvider).invoicesDao.watchAllInvoices();
});

class InvoiceHistoryScreen extends ConsumerStatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  ConsumerState<InvoiceHistoryScreen> createState() =>
      _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends ConsumerState<InvoiceHistoryScreen> {
  String _filter = 'all'; // all | cash | utang | voided

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice History')),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', value: 'all', current: _filter,
                      onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Cash', value: 'cash', current: _filter,
                      onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Utang', value: 'utang', current: _filter,
                      onTap: (v) => setState(() => _filter = v)),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Voided', value: 'voided', current: _filter,
                      onTap: (v) => setState(() => _filter = v)),
                ],
              ),
            ),
          ),
          Expanded(
            child: invoicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (invoices) {
                // Apply filter
                final filtered = invoices.where((inv) {
                  if (_filter == 'all') return inv.status != 'voided';
                  if (_filter == 'voided') return inv.status == 'voided';
                  return inv.type == _filter && inv.status != 'voided';
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No ${_filter == 'all' ? '' : _filter} invoices yet',
                            style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final inv = filtered[i];
                    return _InvoiceTile(
                      invoice: inv,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                InvoiceDetailScreen(invoiceId: inv.id)),
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
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _InvoiceTile extends ConsumerWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  const _InvoiceTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUtang = invoice.type == 'utang';
    final isVoided = invoice.status == 'voided';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isVoided
              ? Colors.grey[200]
              : isUtang
                  ? Colors.orange[100]
                  : Colors.green[100],
          child: Icon(
            isVoided
                ? Icons.cancel_outlined
                : isUtang
                    ? Icons.people_outline
                    : Icons.payments_outlined,
            color: isVoided
                ? Colors.grey
                : isUtang
                    ? Colors.orange[800]
                    : Colors.green[800],
          ),
        ),
        title: Text(
          invoice.invoiceNo,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isVoided ? Colors.grey : null,
            decoration: isVoided ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(formatDateTime(invoice.createdAt)),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatCurrency(invoice.totalCents),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isVoided ? Colors.grey : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isVoided
                    ? Colors.grey[200]
                    : isUtang
                        ? Colors.orange[50]
                        : Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isVoided ? 'VOIDED' : isUtang ? 'UTANG' : 'CASH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isVoided
                      ? Colors.grey
                      : isUtang
                          ? Colors.orange[700]
                          : Colors.green[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}