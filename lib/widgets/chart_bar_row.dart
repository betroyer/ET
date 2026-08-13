import 'package:flutter/material.dart';

import '../utils/currency_formatter.dart';

class ChartBarRow extends StatelessWidget {
  const ChartBarRow({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    this.symbol = '₱',
    this.onTap,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String symbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(CurrencyFormatter.format(value, symbol: symbol)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
