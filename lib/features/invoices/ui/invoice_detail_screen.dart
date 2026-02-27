import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/services/pdf_service.dart';

final invoiceDetailProvider =
    FutureProvider.family<_InvoiceData?, String>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final invoice = await db.invoicesDao.getInvoiceById(id);
  if (invoice == null) return null;
  final items = await db.invoicesDao.getItemsForInvoice(id);
  Customer? customer;
  if (invoice.customerId != null) {
    customer = await db.customersDao.getCustomerById(invoice.customerId!);
  }
  return _InvoiceData(invoice: invoice, items: items, customer: customer);
});

class _InvoiceData {
  final Invoice invoice;
  final List<InvoiceItem> items;
  final Customer? customer;
  _InvoiceData({required this.invoice, required this.items, this.customer});
}

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(invoiceDetailProvider(invoiceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          if (dataAsync.valueOrNull?.invoice.status == 'active')
              PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'void') await _voidInvoice(context, ref, dataAsync.valueOrNull!.invoice);
                    if (v == 'pdf') await _printPdf(context, ref, dataAsync.valueOrNull!);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'pdf', child: ListTile(
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Print / Share PDF'),
                      contentPadding: EdgeInsets.zero,
                    )),
                    const PopupMenuItem(value: 'void', child: ListTile(
                      leading: Icon(Icons.cancel_outlined, color: Colors.red),
                      title: Text('Void Invoice', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    )),
                  ],
                ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Invoice not found'));
          }
          final inv = data.invoice;
          final isVoided = inv.status == 'voided';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                if (isVoided)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('⚠️ This invoice has been VOIDED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                const SizedBox(height: 12),

                // Invoice meta
                _Section(
                  title: 'Invoice Details',
                  children: [
                    _Row('Invoice #', inv.invoiceNo),
                    _Row('Date', formatDateTime(inv.createdAt)),
                    _Row('Type', inv.type.toUpperCase()),
                    if (data.customer != null)
                      _Row('Customer', data.customer!.name),
                    if (inv.notes != null) _Row('Notes', inv.notes!),
                  ],
                ),
                const SizedBox(height: 16),

                // Items
                _Section(
                  title: 'Items',
                  children: data.items
                      .map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.productNameSnapshot} (${item.unitSnapshot})',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Text('x${item.qty}',
                                    style: TextStyle(color: Colors.grey[600])),
                                const SizedBox(width: 8),
                                Text(
                                  formatCurrency(item.priceSnapshotCents),
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    formatCurrency(item.lineTotalCents),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),

                // Totals
                _Section(
                  title: 'Summary',
                  children: [
                    _Row('Subtotal', formatCurrency(inv.subtotalCents)),
                    if (inv.discountCents > 0)
                      _Row('Discount', '- ${formatCurrency(inv.discountCents)}',
                          valueColor: Colors.green),
                    const Divider(),
                    _Row('TOTAL', formatCurrency(inv.totalCents),
                        bold: true, valueSize: 20),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _voidInvoice(
      BuildContext context, WidgetRef ref, Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Void Invoice?'),
        content: Text(
          'This will reverse all stock changes and ${invoice.type == 'utang' ? 'reduce the customer\'s balance.' : 'mark the invoice as voided.'}\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void Invoice',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(databaseProvider).invoicesDao.voidInvoice(invoice.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice voided'), backgroundColor: Colors.orange),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _printPdf(
      BuildContext context, WidgetRef ref, _InvoiceData data) async {
    try {
      final settings = ref.read(settingsProvider);
      await PdfService.printReceipt(
        invoice: data.invoice,
        items: data.items,
        customer: data.customer,
        storeName: settings.storeName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final double? valueSize;
  const _Row(this.label, this.value,
      {this.valueColor, this.bold = false, this.valueSize});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
                fontSize: valueSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}