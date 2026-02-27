import 'package:drift/drift.dart';
import '../app_database.dart';

part 'reports_dao.g.dart';

class SalesReport {
  final int totalSalesCents;
  final int invoiceCount;
  final int itemsSold;

  SalesReport({required this.totalSalesCents, required this.invoiceCount, required this.itemsSold});
}

class BestSellerItem {
  final String productId;
  final String productName;
  final int totalQty;
  final int totalRevenueCents;

  BestSellerItem({required this.productId, required this.productName, required this.totalQty, required this.totalRevenueCents});
}

@DriftAccessor(tables: [Invoices, InvoiceItems, Customers, StockMovements])
class ReportsDao extends DatabaseAccessor<AppDatabase> with _$ReportsDaoMixin {
  ReportsDao(super.db);

  Future<SalesReport> getSalesReport(DateTime from, DateTime to) async {
    final result = await customSelect(
      '''SELECT 
          COALESCE(SUM(total_cents), 0) as total,
          COUNT(*) as cnt
         FROM invoices 
         WHERE status = 'active' 
           AND created_at >= ? AND created_at <= ?''',
      variables: [Variable(from), Variable(to)],
      readsFrom: {db.invoices},
    ).getSingle();

    final itemsResult = await customSelect(
      '''SELECT COALESCE(SUM(ii.qty), 0) as total_items
         FROM invoice_items ii
         JOIN invoices i ON ii.invoice_id = i.id
         WHERE i.status = 'active'
           AND i.created_at >= ? AND i.created_at <= ?''',
      variables: [Variable(from), Variable(to)],
      readsFrom: {db.invoices, db.invoiceItems},
    ).getSingle();

    return SalesReport(
      totalSalesCents: result.data['total'] as int,
      invoiceCount: result.data['cnt'] as int,
      itemsSold: itemsResult.data['total_items'] as int,
    );
  }

  Future<List<BestSellerItem>> getBestSellers(DateTime from, DateTime to, {int limit = 10}) async {
    final rows = await customSelect(
      '''SELECT 
          ii.product_id,
          ii.product_name_snapshot as product_name,
          SUM(ii.qty) as total_qty,
          SUM(ii.line_total_cents) as total_revenue
         FROM invoice_items ii
         JOIN invoices i ON ii.invoice_id = i.id
         WHERE i.status = 'active'
           AND i.created_at >= ? AND i.created_at <= ?
         GROUP BY ii.product_id, ii.product_name_snapshot
         ORDER BY total_qty DESC
         LIMIT ?''',
      variables: [Variable(from), Variable(to), Variable(limit)],
      readsFrom: {db.invoices, db.invoiceItems},
    ).get();

    return rows.map((row) => BestSellerItem(
      productId: row.data['product_id'] as String,
      productName: row.data['product_name'] as String,
      totalQty: row.data['total_qty'] as int,
      totalRevenueCents: row.data['total_revenue'] as int,
    )).toList();
  }

  Future<int> getTotalOutstandingUtang() async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(balance_cents), 0) as total FROM customers',
      readsFrom: {db.customers},
    ).getSingle();
    return result.data['total'] as int;
  }
}