import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/chart_bar_row.dart';
import '../../widgets/transaction_tile.dart';
import '../transactions/transaction_detail_screen.dart';

enum ReportPeriod { daily, weekly, monthly }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _period = ReportPeriod.monthly;
  Map<String, double> _breakdown = {};
  List<TransactionModel> _periodTx = [];
  double _income = 0;
  double _expenses = 0;
  bool _loading = true;
  String? _drillCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    switch (_period) {
      case ReportPeriod.daily:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start);
      case ReportPeriod.weekly:
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return (start, end);
      case ReportPeriod.monthly:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (start, end);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _range();
    final provider = context.read<TransactionProvider>();
    final tx = await provider.forPeriod(start: start, end: end);
    final breakdown = await provider.categoryBreakdown(start: start, end: end);
    if (!mounted) return;
    setState(() {
      _periodTx = tx;
      _breakdown = breakdown;
      _income = tx.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
      _expenses = tx.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final colors = [
      Theme.of(context).colorScheme.primary,
      const Color(0xFF0EA5E9),
      const Color(0xFFD97706),
      const Color(0xFFE11D48),
      const Color(0xFF8B5CF6),
      const Color(0xFF059669),
    ];

    if (_drillCategory != null) {
      final filtered = _periodTx.where((t) => t.isExpense && t.category == _drillCategory).toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(_drillCategory!),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _drillCategory = null),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: filtered
              .map(
                (t) => TransactionTile(
                  transaction: t,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: t.id!)),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  SegmentedButton<ReportPeriod>(
                    segments: const [
                      ButtonSegment(value: ReportPeriod.daily, label: Text('Daily')),
                      ButtonSegment(value: ReportPeriod.weekly, label: Text('Weekly')),
                      ButtonSegment(value: ReportPeriod.monthly, label: Text('Monthly')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (s) {
                      setState(() => _period = s.first);
                      _load();
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${DateFormatter.displayDate(_range().$1)} – ${DateFormatter.displayDate(_range().$2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _SummaryCard(label: 'Spent', value: CurrencyFormatter.format(_expenses, symbol: symbol))),
                      const SizedBox(width: 10),
                      Expanded(child: _SummaryCard(label: 'Income', value: CurrencyFormatter.format(_income, symbol: symbol))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Balance',
                          value: CurrencyFormatter.format(_income - _expenses, symbol: symbol),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('By category', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_breakdown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No expenses in this period.'),
                    )
                  else ...[
                    ..._breakdown.entries.toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      final max = _breakdown.values.fold<double>(0, (a, b) => a > b ? a : b);
                      return ChartBarRow(
                        label: e.key,
                        value: e.value,
                        maxValue: max,
                        color: colors[i % colors.length],
                        symbol: symbol,
                        onTap: () => setState(() => _drillCategory = e.key),
                      );
                    }),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 42,
                          sections: _breakdown.entries.toList().asMap().entries.map((entry) {
                            final i = entry.key;
                            final e = entry.value;
                            final total = _expenses <= 0 ? 1 : _expenses;
                            return PieChartSectionData(
                              color: colors[i % colors.length],
                              value: e.value,
                              title: '${((e.value / total) * 100).round()}%',
                              radius: 58,
                              titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: _breakdown.entries.toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(e.key),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
