import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../data/db/daos/reports_dao.dart';
import '../../settings/ui/settings_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = 'today';
  bool _loading = false;
  _ReportData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_period) {
      case 'today':
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
      case 'week':
        return DateTimeRange(
            start: now.subtract(const Duration(days: 7)), end: now);
      case 'month':
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: now);
      case 'year':
        return DateTimeRange(
            start: DateTime(now.year, 1, 1), end: now);
      default:
        return DateTimeRange(start: now, end: now);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(databaseProvider);
      final range = _range;
      final sales = await db.reportsDao.getSalesReport(range.start, range.end);
      final bestSellers =
          await db.reportsDao.getBestSellers(range.start, range.end, limit: 10);
      final totalUtang = await db.reportsDao.getTotalOutstandingUtang();
      final topDebtors = await db.customersDao.searchCustomers('');
      topDebtors.sort((a, b) => b.balanceCents.compareTo(a.balanceCents));

      final profitCents = await _estimateProfit(db, range.start, range.end);
      final avgTransactionCents = sales.invoiceCount > 0 
          ? (sales.totalSalesCents / sales.invoiceCount).round()
          : 0;

      if (mounted) {
        setState(() {
          _data = _ReportData(
            sales: sales,
            bestSellers: bestSellers,
            totalUtang: totalUtang,
            topDebtors: topDebtors.take(5).toList(),
            estimatedProfitCents: profitCents,
            avgTransactionCents: avgTransactionCents,
            from: range.start,
            to: range.end,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<int> _estimateProfit(dynamic db, DateTime from, DateTime to) async {
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
        variables: [Variable(from), Variable(to)],
        readsFrom: {db.invoices, db.invoiceItems, db.products},
      ).getSingle();
      return result.data['profit'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Period Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in [
                    ('today', 'Today', Icons.today_outlined),
                    ('week', '7 Days', Icons.date_range_outlined),
                    ('month', 'This Month', Icons.calendar_month_outlined),
                    ('year', 'This Year', Icons.calendar_today_outlined),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: _period == period.$1 ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            setState(() => _period = period.$1);
                            _load();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _period == period.$1 
                                    ? AppTheme.primary 
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  period.$3,
                                  size: 18,
                                  color: _period == period.$1 
                                      ? Colors.white 
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  period.$2,
                                  style: TextStyle(
                                    color: _period == period.$1 
                                        ? Colors.white 
                                        : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _data == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No data available',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : _ReportBody(data: _data!),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final _ReportData data;
  const _ReportBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final profitMargin = data.sales.totalSalesCents > 0
        ? (data.estimatedProfitCents / data.sales.totalSalesCents * 100)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Date Range
        Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              '${formatDate(data.from)} – ${formatDate(data.to)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Main KPIs - 2x2 Grid
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Sales',
                value: formatCurrency(data.sales.totalSalesCents),
                icon: Icons.payments_outlined,
                color: Colors.blue,
                trend: data.sales.invoiceCount > 0 ? '+${data.sales.invoiceCount}' : null,
                trendLabel: 'transactions',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Est. Profit',
                value: data.estimatedProfitCents > 0
                    ? formatCurrency(data.estimatedProfitCents)
                    : 'N/A',
                icon: Icons.trending_up,
                color: data.estimatedProfitCents > 0 ? Colors.green : Colors.grey,
                trend: profitMargin > 0 ? '${profitMargin.toStringAsFixed(1)}%' : null,
                trendLabel: 'margin',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Items Sold',
                value: '${data.sales.itemsSold}',
                icon: Icons.shopping_bag_outlined,
                color: Colors.teal,
                trend: data.sales.invoiceCount > 0 
                    ? '${(data.sales.itemsSold / data.sales.invoiceCount).toStringAsFixed(1)}'
                    : null,
                trendLabel: 'per transaction',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Avg. Sale',
                value: formatCurrency(data.avgTransactionCents),
                icon: Icons.receipt_long_outlined,
                color: Colors.indigo,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Outstanding Utang Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: data.totalUtang > 0
                  ? [Colors.orange.shade400, Colors.orange.shade600]
                  : [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (data.totalUtang > 0 ? Colors.orange : Colors.green).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  data.totalUtang > 0 ? Icons.people_outline : Icons.check_circle_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Utang',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(data.totalUtang),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (data.topDebtors.isNotEmpty)
                      Text(
                        '${data.topDebtors.length} customer${data.topDebtors.length > 1 ? 's' : ''} with balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Best Sellers Section
        if (data.bestSellers.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.star, size: 18, color: Colors.amber.shade700),
              ),
              const SizedBox(width: 10),
              const Text(
                'Best Sellers',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
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
            child: Column(
              children: data.bestSellers.asMap().entries.map((e) {
                final rank = e.key + 1;
                final item = e.value;
                final maxQty = data.bestSellers.first.totalQty;
                final ratio = maxQty > 0 ? item.totalQty / maxQty : 0.0;
                
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: rank <= 3 
                                      ? Colors.amber.shade50 
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: rank <= 3 
                                          ? Colors.amber.shade700 
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.totalQty} units sold',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatCurrency(item.totalRevenueCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                rank <= 3 ? Colors.amber.shade400 : Colors.blue.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rank < data.bestSellers.length)
                      Divider(height: 1, color: Colors.grey.shade200),
                  ],
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 28),

        // Top Debtors Section
        if (data.topDebtors.isNotEmpty && data.totalUtang > 0) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_outlined, size: 18, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 10),
              const Text(
                'Top Debtors',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
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
            child: Column(
              children: data.topDebtors.asMap().entries.map((e) {
                final c = e.value;
                final isLast = e.key == data.topDebtors.length - 1;
                
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.orange.shade100,
                            child: Text(
                              c.name[0].toUpperCase(),
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (c.phone != null)
                                  Text(
                                    c.phone!,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            formatCurrency(c.balanceCents),
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Divider(height: 1, color: Colors.grey.shade200),
                  ],
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final String? trendLabel;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.trendLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (trend != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$trend ${trendLabel ?? ''}',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _ReportData {
  final SalesReport sales;
  final List<BestSellerItem> bestSellers;
  final int totalUtang;
  final List<dynamic> topDebtors;
  final int estimatedProfitCents;
  final int avgTransactionCents;
  final DateTime from;
  final DateTime to;

  _ReportData({
    required this.sales,
    required this.bestSellers,
    required this.totalUtang,
    required this.topDebtors,
    required this.estimatedProfitCents,
    required this.avgTransactionCents,
    required this.from,
    required this.to,
  });
}
