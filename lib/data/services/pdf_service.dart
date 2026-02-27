import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/db/app_database.dart';
import '../../core/utils/currency.dart';
import '../../core/utils/date_utils.dart';

class PdfService {
  // ─── Receipt PDF ────────────────────────────────────────────────────────────

  static Future<void> printReceipt({
    required Invoice invoice,
    required List<InvoiceItem> items,
    Customer? customer,
    String storeName = 'Sari-sari Store',
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(8),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Store header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(storeName,
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(invoice.invoiceNo,
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.Text(formatDateTime(invoice.createdAt),
                      style: const pw.TextStyle(fontSize: 10)),
                  if (customer != null)
                    pw.Text('Customer: ${customer.name}',
                        style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 4),

            // Items
            ...items.map((item) => pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${item.productNameSnapshot}\n  x${item.qty} @ ${formatCurrency(item.priceSnapshotCents)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.Text(formatCurrency(item.lineTotalCents),
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            )),

            pw.SizedBox(height: 4),
            pw.Divider(),

            // Totals
            if (invoice.discountCents > 0)
              _receiptRow('Discount', '- ${formatCurrency(invoice.discountCents)}'),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(formatCurrency(invoice.totalCents),
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                color: invoice.type == 'utang' ? PdfColors.orange50 : PdfColors.green50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Center(
                child: pw.Text(
                  invoice.type == 'utang' ? 'UTANG' : 'CASH',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: invoice.type == 'utang'
                        ? PdfColors.orange800
                        : PdfColors.green800,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            if (invoice.notes != null) ...[
              pw.Text('Note: ${invoice.notes}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),
            ],
            pw.Center(child: pw.Text('Thank you!', style: const pw.TextStyle(fontSize: 11))),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  static pw.Widget _receiptRow(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  // ─── Customer Statement PDF ──────────────────────────────────────────────────

  static Future<void> printCustomerStatement({
    required Customer customer,
    required List<PdfLedgerEntry> ledger,
    String storeName = 'Sari-sari Store',
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(storeName,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Account Statement',
                    style: const pw.TextStyle(fontSize: 13)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(customer.name,
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (customer.phone != null)
                  pw.Text(customer.phone!,
                      style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Printed: ${formatDateTime(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10)),
              ]),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.SizedBox(height: 8),

          // Table header
          _stmtRow('Date', 'Description', 'Debit', 'Credit', 'Balance',
              isHeader: true),
          pw.Divider(),

          // Ledger rows
          ...() {
            int runningBalance = 0;
            return ledger.map((entry) {
              if (entry.type == 'utang') {
                runningBalance += entry.amountCents;
              } else {
                runningBalance -= entry.amountCents;
              }
              return _stmtRow(
                formatDate(entry.date),
                entry.description,
                entry.type == 'utang' ? formatCurrency(entry.amountCents) : '',
                entry.type == 'payment' ? formatCurrency(entry.amountCents) : '',
                formatCurrency(runningBalance.clamp(0, 999999999)),
              );
            });
          }().toList(),

          pw.SizedBox(height: 8),
          pw.Divider(),

          // Balance summary
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Current Balance: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(
                formatCurrency(customer.balanceCents),
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: customer.balanceCents > 0 ? PdfColors.red : PdfColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  static pw.Widget _stmtRow(
    String col1,
    String col2,
    String col3,
    String col4,
    String col5, {
    bool isHeader = false,
  }) {
    final style = isHeader
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)
        : const pw.TextStyle(fontSize: 10);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 60, child: pw.Text(col1, style: style)),
          pw.Expanded(child: pw.Text(col2, style: style)),
          pw.SizedBox(width: 70, child: pw.Text(col3, style: style, textAlign: pw.TextAlign.right)),
          pw.SizedBox(width: 70, child: pw.Text(col4, style: style, textAlign: pw.TextAlign.right)),
          pw.SizedBox(width: 70, child: pw.Text(col5, style: style, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }
}

class PdfLedgerEntry {
  final DateTime date;
  final String type; // 'utang' | 'payment'
  final String description;
  final int amountCents;
  PdfLedgerEntry(
      {required this.date,
      required this.type,
      required this.description,
      required this.amountCents});
}