import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../core/utils/date_utils.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../app/providers.dart';
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
          await db.reportsDao.getBestSellers(range.start, range.end, limit: 8);
      final totalUtang = await db.reportsDao.getTotalOutstandingUtang();
      final topDebtors = await db.customersDao.searchCustomers('');
      topDebtors.sort((a, b) => b.balanceCents.compareTo(a.balanceCents));

      final profitCents = await _estimateProfit(db, range.start, range.end);

      if (mounted) {
        setState(() {
          _data = _ReportData(
            sales: sales,
            bestSellers: bestSellers,
            totalUtang: totalUtang,
            topDebtors: topDebtors.take(5).toList(),
            estimatedProfitCents: profitCents,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
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
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final period in [
                    ('today', 'Today'),
                    ('week', '7 Days'),
                    ('month', 'This Month'),
                    ('year', 'This Year'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(period.$2),
                        selected: _period == period.$1,
                        onSelected: (v) {
                          if (v) {
                            setState(() => _period = period.$1);
                            _load();
                          }
                        },
                        backgroundColor: const Color(0xFFF8F9FA),
                        selectedColor: const Color(0xFF2D5F3F),
                        labelStyle: TextStyle(
                          color: _period == period.$1 ? Colors.white : const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _period == period.$1 ? const Color(0xFF2D5F3F) : Colors.grey.shade300,
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
                    ? const Center(child: Text('No data'))
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          '${formatDate(data.from)} – ${formatDate(data.to)}',
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Total Sales',
                value: formatCurrency(data.sales.totalSalesCents),
                icon: Icons.payments_outlined,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                title: 'Transactions',
                value: '${data.sales.invoiceCount}',
                icon: Icons.receipt_outlined,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'Items Sold',
                value: '${data.sales.itemsSold}',
                icon: Icons.shopping_bag_outlined,
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _KpiCard(
                title: 'Est. Profit',
                value: data.estimatedProfitCents > 0
                    ? formatCurrency(data.estimatedProfitCents)
                    : 'N/A',
                subtitle: data.estimatedProfitCents == 0
                    ? 'Add product costs'
                    : null,
                icon: Icons.trending_up,
                color: data.estimatedProfitCents > 0
                    ? Colors.green
                    : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _KpiCard(
          title: 'Outstanding Utang',
          value: formatCurrency(data.totalUtang),
          icon: Icons.people_outline,
          color: data.totalUtang > 0 ? Colors.orange : Colors.green,
          wide: true,
        ),

        const SizedBox(height: 20),

        if (data.bestSellers.isNotEmpty) ...[
          _SectionTitle('Best Sellers', Icons.star_outline),
          const SizedBox(height: 12),
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
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '$rank.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: rank <= 3 ? Colors.amber[700] : Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(item.productName,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          Text('${item.totalQty} sold',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(width: 8),
                          Text(formatCurrency(item.totalRevenueCents),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 4,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(Colors.blue[400]),
                        ),
                      ),
                      if (rank < data.bestSellers.length) const Divider(height: 12),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 20),

        if (data.topDebtors.isNotEmpty && data.totalUtang > 0) ...[
          _SectionTitle('Top Debtors', Icons.warning_amber_outlined),
          const SizedBox(height: 12),
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
              children: data.topDebtors.map((c) {
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.orange[100],
                    child: Text(c.name[0].toUpperCase(),
                        style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(c.name),
                  subtitle: c.phone != null ? Text(c.phone!) : null,
                  trailing: Text(
                    formatCurrency(c.balanceCents),
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool wide;
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: wide
            ? Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      Text(value,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(value,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle ?? title,
                      style:
                          const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                ],
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1A1A1A))),
      ],
    );
  }
}

class _ReportData {
  final SalesReport sales;
  final List<BestSellerItem> bestSellers;
  final int totalUtang;
  final List<dynamic> topDebtors;
  final int estimatedProfitCents;
  final DateTime from;
  final DateTime to;

  _ReportData({
    required this.sales,
    required this.bestSellers,
    required this.totalUtang,
    required this.topDebtors,
    required this.estimatedProfitCents,
    required this.from,
    required this.to,
  });
}
