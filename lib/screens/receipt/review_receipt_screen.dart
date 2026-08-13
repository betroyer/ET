import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/receipt_item.dart';
import '../../models/transaction.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/receipt_parser.dart';
import '../../utils/constants.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class ReviewReceiptScreen extends StatefulWidget {
  const ReviewReceiptScreen({
    super.key,
    required this.parsed,
    this.imagePath,
  });

  final ParsedReceipt parsed;
  final String? imagePath;

  @override
  State<ReviewReceiptScreen> createState() => _ReviewReceiptScreenState();
}

class _ReviewReceiptScreenState extends State<ReviewReceiptScreen> {
  late final TextEditingController _totalCtrl;
  late final TextEditingController _cashCtrl;
  late final TextEditingController _changeCtrl;
  late final TextEditingController _noteCtrl;
  late List<ReceiptItem> _items;
  String? _category;
  String _payment = AppConstants.paymentMethods.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.parsed.items);
    _totalCtrl = TextEditingController(
      text: widget.parsed.total?.toStringAsFixed(2) ?? '',
    );
    _cashCtrl = TextEditingController(
      text: widget.parsed.cashTendered?.toStringAsFixed(2) ?? '',
    );
    _changeCtrl = TextEditingController(
      text: widget.parsed.change?.toStringAsFixed(2) ?? '',
    );
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _cashCtrl.dispose();
    _changeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>().byType('expense');
    _category ??= categories.isNotEmpty ? categories.first.name : 'Others';
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final scheme = Theme.of(context).colorScheme;
    final foundTotal = widget.parsed.total;
    final itemCount = _items.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt expenses')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanned automatically',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  itemCount > 0
                      ? 'Found $itemCount item${itemCount == 1 ? '' : 's'}'
                          '${foundTotal != null ? ' · total ${CurrencyFormatter.format(foundTotal, symbol: symbol)}' : ''}'
                      : 'No line items detected — enter the total below, or add items manually.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (widget.imagePath != null && File(widget.imagePath!).existsSync()) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(widget.imagePath!), height: 140, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'Expenses on receipt',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _items.add(const ReceiptItem(itemName: '', price: 0));
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No items yet. Add them or set the total amount below.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ..._items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: item.itemName,
                      decoration: const InputDecoration(
                        labelText: 'Item / expense',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _items[i] = item.copyWith(itemName: v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.price == 0 ? '' : item.price.toStringAsFixed(2),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Amount',
                              prefixText: '$symbol ',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final n = double.tryParse(v.replaceAll(',', '')) ?? 0;
                              _items[i] = item.copyWith(price: n);
                              _maybeSyncTotalFromItems();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: TextFormField(
                            initialValue: '${item.quantity}',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v) ?? 1;
                              _items[i] = item.copyWith(quantity: n);
                              _maybeSyncTotalFromItems();
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() => _items.removeAt(i));
                            _maybeSyncTotalFromItems();
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          TextFormField(
            controller: _totalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Expense total',
              prefixText: '$symbol ',
              border: const OutlineInputBorder(),
              helperText: 'This becomes the expense amount saved in ExTra',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cashCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Cash paid',
                    prefixText: '$symbol ',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _changeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Change',
                    prefixText: '$symbol ',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: categories
                .map((c) => DropdownMenuItem(value: c.name, child: Text('${c.icon} ${c.name}')))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _payment,
            decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()),
            items: AppConstants.paymentMethods
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _payment = v ?? _payment),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save expense'),
          ),
        ),
      ),
    );
  }

  void _maybeSyncTotalFromItems() {
    if (_items.isEmpty) return;
    final sum = _items.fold<double>(0, (s, i) => s + i.lineTotal);
    if (sum > 0) {
      _totalCtrl.text = sum.toStringAsFixed(2);
      setState(() {});
    }
  }

  Future<void> _save() async {
    var total = double.tryParse(_totalCtrl.text.replaceAll(',', ''));
    if ((total == null || total <= 0) && _items.isNotEmpty) {
      total = _items.fold<double>(0, (s, i) => s + i.lineTotal);
    }
    if (total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid expense total')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final tx = TransactionModel(
      type: 'expense',
      amount: total,
      category: _category ?? 'Others',
      date: DateFormatter.isoDate(now),
      time: DateFormatter.isoTime(now),
      paymentMethod: _payment,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      receiptImagePath: widget.imagePath,
    );
    await context.read<TransactionProvider>().add(
          tx,
          items: _items.where((i) => i.itemName.trim().isNotEmpty || i.price > 0).toList(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense saved from receipt')),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
