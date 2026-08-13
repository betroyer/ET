import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/quick_add_buttons.dart';
import '../../widgets/transaction_tile.dart';
import '../receipt/scan_receipt_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/add_expense_screen.dart';
import '../transactions/add_income_screen.dart';
import '../transactions/transaction_detail_screen.dart';
import '../reports/reports_screen.dart';
import '../../providers/settings_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openExpense(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  Future<void> _openExpense(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddExpenseScreen()));
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final tx = context.watch<TransactionProvider>();
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<TransactionProvider>().load(),
          context.read<BudgetProvider>().load(),
        ]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const AppLogo(size: 36, showTitle: true),
            actions: [
              IconButton(
                tooltip: 'Scan receipt',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
                ),
                icon: const Icon(Icons.document_scanner_outlined),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList.list(
              children: [
                const BalanceCard(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.today, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Today's expenses",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(tx.todayExpenses, symbol: symbol),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                QuickAddButtons(
                  onAddExpense: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                  ),
                  onAddIncome: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
                  ),
                  onScanReceipt: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Recent', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                if (tx.loading && tx.transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tx.recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions yet.\nAdd an expense or scan a receipt.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  )
                else
                  ...tx.recent.map(
                    (t) => TransactionTile(
                      transaction: t,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(transactionId: t.id!),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
