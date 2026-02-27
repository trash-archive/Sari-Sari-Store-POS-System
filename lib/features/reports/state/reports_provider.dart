import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import '../../../app/providers.dart';
import '../../../data/db/daos/reports_dao.dart';

class ReportData {
  final SalesReport sales;
  final List<BestSellerItem> bestSellers;
  final int totalUtang;
  final int estimatedProfitCents;
  final DateTime from;
  final DateTime to;

  ReportData({
    required this.sales,
    required this.bestSellers,
    required this.totalUtang,
    required this.estimatedProfitCents,
    required this.from,
    required this.to,
  });
}

final reportsProvider = FutureProvider.family<ReportData, DateTimeRange>((ref, range) async {
  final db = ref.watch(databaseProvider);
  
  final sales = await db.reportsDao.getSalesReport(range.start, range.end);
  final bestSellers = await db.reportsDao.getBestSellers(range.start, range.end, limit: 8);
  final totalUtang = await db.reportsDao.getTotalOutstandingUtang();
  
  int profitCents = 0;
  try {
    final result = await db.customSelect(
      '''
      SELECT 
        COALESCE(SUM(ii.line_total_cents - COALESCE(p.cost_cents, 0) * ii.qty), 0) as profit
      FROM invoice_items ii
      JOIN invoices i ON i.id = ii.invoice_id
      JOIN products p ON p.id = ii.product_id
      WHERE i.status = 'active'
        AND i.created_at >= ? AND i.created_at <= ?
      ''',
      variables: [Variable(range.start), Variable(range.end)],
      readsFrom: {db.invoices, db.invoiceItems, db.products},
    ).getSingle();
    profitCents = result.data['profit'] as int? ?? 0;
  } catch (_) {}
  
  return ReportData(
    sales: sales,
    bestSellers: bestSellers,
    totalUtang: totalUtang,
    estimatedProfitCents: profitCents,
    from: range.start,
    to: range.end,
  );
});
