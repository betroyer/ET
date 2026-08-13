import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/currency_formatter.dart';

class BudgetSettingsScreen extends StatefulWidget {
  const BudgetSettingsScreen({super.key});

  @override
  State<BudgetSettingsScreen> createState() => _BudgetSettingsScreenState();
}

class _BudgetSettingsScreenState extends State<BudgetSettingsScreen> {
  final _overallCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<BudgetProvider>().load();
      if (!mounted) return;
      final overall = context.read<BudgetProvider>().overall;
      if (overall != null) {
        _overallCtrl.text = overall.limitAmount.toStringAsFixed(2);
      }
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _overallCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetProvider>();
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final categories = context.watch<CategoryProvider>().byType('expense');

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly budget')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _overallCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Overall monthly limit',
                    prefixText: '$symbol ',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final n = double.tryParse(_overallCtrl.text.replaceAll(',', ''));
                    if (n == null || n <= 0) return;
                    await context.read<BudgetProvider>().saveOverall(n);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Budget saved')),
                      );
                    }
                  },
                  child: const Text('Save overall budget'),
                ),
                const SizedBox(height: 24),
                Text('Category budgets', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...categories.map((c) {
                  final existing = budget.budgets.where((b) => b.category == c.name).firstOrNull;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(c.icon, style: const TextStyle(fontSize: 22)),
                    title: Text(c.name),
                    subtitle: Text(
                      existing == null
                          ? 'Not set'
                          : CurrencyFormatter.format(existing.limitAmount, symbol: symbol),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editCategory(context, c.name, existing?.limitAmount),
                  );
                }),
              ],
            ),
    );
  }

  Future<void> _editCategory(BuildContext context, String category, double? current) async {
    final ctrl = TextEditingController(text: current?.toStringAsFixed(2) ?? '');
    final symbol = context.read<SettingsProvider>().currencySymbol;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$category budget'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: '$symbol ', labelText: 'Limit'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final n = double.tryParse(ctrl.text.replaceAll(',', ''));
      if (n == null || n <= 0) return;
      await context.read<BudgetProvider>().saveCategory(category: category, limit: n);
    }
  }
}
