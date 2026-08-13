import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final int transactionId;

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final txProvider = context.watch<TransactionProvider>();
    final tx = txProvider.transactions.where((t) => t.id == widget.transactionId).firstOrNull;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    if (tx == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tx.isExpense ? 'Expense' : 'Income'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete transaction?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await context.read<TransactionProvider>().remove(tx.id!);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${tx.isExpense ? '-' : '+'}${CurrencyFormatter.format(tx.amount, symbol: symbol)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tx.isExpense ? Theme.of(context).colorScheme.error : const Color(0xFF059669),
                ),
          ),
          const SizedBox(height: 8),
          Text(tx.category, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _InfoRow(label: 'Date', value: DateFormatter.displayDateTime(tx.dateTime)),
          if (tx.paymentMethod != null) _InfoRow(label: 'Payment', value: tx.paymentMethod!),
          if (tx.source != null) _InfoRow(label: 'Source', value: tx.source!),
          if ((tx.note ?? '').isNotEmpty) _InfoRow(label: 'Note', value: tx.note!),
          if (tx.items.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Receipt items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...tx.items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.itemName),
                subtitle: Text('Qty ${item.quantity}'),
                trailing: Text(CurrencyFormatter.format(item.lineTotal, symbol: symbol)),
              ),
            ),
          ],
          if (tx.receiptImagePath != null && File(tx.receiptImagePath!).existsSync()) ...[
            const SizedBox(height: 20),
            Text('Receipt photo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(tx.receiptImagePath!), fit: BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
