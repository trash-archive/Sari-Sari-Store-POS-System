import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/services/pdf_service.dart';

final invoiceDetailProvider =
    FutureProvider.autoDispose.family<_InvoiceData?, String>((ref, id) async {
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Invoice', style: TextStyle(fontWeight: FontWeight.w600)),
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
            child: Column(
              children: [
                // Receipt Container
                Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Receipt Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.05),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.store, size: 32, color: AppTheme.primary),
                            const SizedBox(height: 8),
                            const Text(
                              'TindaKo',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'SALES RECEIPT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Void Warning
                      if (isVoided)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Colors.red.shade50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'VOIDED TRANSACTION',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Receipt Body
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Invoice Details
                            _ReceiptRow('Receipt #:', inv.invoiceNo, bold: true),
                            const SizedBox(height: 4),
                            _ReceiptRow('Date:', formatDateTime(inv.createdAt)),
                            const SizedBox(height: 4),
                            _ReceiptRow('Type:', inv.type.toUpperCase()),
                            if (data.customer != null)
                              const SizedBox(height: 4),
                            if (data.customer != null)
                              _ReceiptRow('Customer:', data.customer!.name, overflow: true),
                            if (inv.notes != null)
                              const SizedBox(height: 4),
                            if (inv.notes != null)
                              _ReceiptRow('Notes:', inv.notes!),
                            
                            const SizedBox(height: 20),
                            
                            // Dashed Line
                            _DashedLine(),
                            const SizedBox(height: 16),
                            
                            // Items Header
                            const Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'ITEM',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    'QTY',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    'PRICE',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    'TOTAL',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Items
                            ...data.items.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${item.productNameSnapshot} (${item.unitSnapshot})',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${item.qty}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      formatCurrency(item.priceSnapshotCents),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      formatCurrency(item.lineTotalCents),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            
                            const SizedBox(height: 16),
                            _DashedLine(),
                            const SizedBox(height: 16),
                            
                            // Totals
                            if (inv.discountCents > 0)
                              _ReceiptRow('Discount:', '- ${formatCurrency(inv.discountCents)}', valueColor: Colors.green.shade700),
                            if (inv.discountCents > 0)
                              const SizedBox(height: 8),
                            _ReceiptRow('TOTAL:', formatCurrency(inv.totalCents), bold: true, fontSize: 18),
                            
                            if (inv.type == 'cash' && inv.cashReceivedCents != null)
                              const SizedBox(height: 12),
                            if (inv.type == 'cash' && inv.cashReceivedCents != null)
                              _DashedLine(),
                            if (inv.type == 'cash' && inv.cashReceivedCents != null)
                              const SizedBox(height: 12),
                            if (inv.type == 'cash' && inv.cashReceivedCents != null)
                              _ReceiptRow('Cash Received:', formatCurrency(inv.cashReceivedCents!)),
                            if (inv.changeCents != null && inv.changeCents! > 0)
                              const SizedBox(height: 4),
                            if (inv.changeCents != null && inv.changeCents! > 0)
                              _ReceiptRow('Change:', formatCurrency(inv.changeCents!), valueColor: Colors.blue.shade700),
                            
                            const SizedBox(height: 20),
                            _DashedLine(),
                            const SizedBox(height: 16),
                            
                            // Footer
                            const Center(
                              child: Text(
                                'Thank you for your business!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Transaction Photo
                if (inv.photoPath != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Transaction Photo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          child: Image.file(
                            File(inv.photoPath!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
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

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final double? fontSize;
  final bool overflow;
  const _ReceiptRow(this.label, this.value, {this.valueColor, this.bold = false, this.fontSize, this.overflow = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: overflow ? 1 : null,
            overflow: overflow ? TextOverflow.ellipsis : null,
            style: TextStyle(
              fontSize: fontSize ?? 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        30,
        (index) => Expanded(
          child: Container(
            height: 1,
            color: index % 2 == 0 ? Colors.grey.shade400 : Colors.transparent,
          ),
        ),
      ),
    );
  }
}