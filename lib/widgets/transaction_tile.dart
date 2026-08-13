import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'category_icon.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final TransactionModel transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final icon = context.watch<CategoryProvider>().iconFor(transaction.category);
    final isExpense = transaction.isExpense;
    final amountColor = isExpense
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF059669);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CategoryIcon(emoji: icon),
      title: Text(
        transaction.category,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          DateFormatter.friendly(transaction.dateTime),
          if ((transaction.note ?? '').isNotEmpty) transaction.note!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${isExpense ? '-' : '+'}${CurrencyFormatter.format(transaction.amount, symbol: symbol)}',
        style: TextStyle(
          color: amountColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
