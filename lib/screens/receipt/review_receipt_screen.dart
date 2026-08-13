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
    final ref = widget.parsed.reference;
    _noteCtrl = TextEditingController(
      text: ref == null ? '' : 'QR ref: $ref',
    );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Review Receipt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          if (widget.imagePath != null && File(widget.imagePath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(widget.imagePath!), height: 160, fit: BoxFit.cover),
            ),
          if ((widget.parsed.rawText).isNotEmpty && widget.imagePath == null) ...[
            Text(widget.parsed.rawText, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _totalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Total',
              prefixText: '$symbol ',
              border: const OutlineInputBorder(),
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
                    labelText: 'Cash tendered',
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
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _items.add(const ReceiptItem(itemName: 'Item', price: 0));
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ],
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
                      decoration: const InputDecoration(labelText: 'Item name'),
                      onChanged: (v) => _items[i] = item.copyWith(itemName: v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.price.toStringAsFixed(2),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: 'Price', prefixText: '$symbol '),
                            onChanged: (v) {
                              final n = double.tryParse(v.replaceAll(',', '')) ?? 0;
                              _items[i] = item.copyWith(price: n);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: '${item.quantity}',
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Qty'),
                            onChanged: (v) {
                              final n = int.tryParse(v) ?? 1;
                              _items[i] = item.copyWith(quantity: n);
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _items.removeAt(i)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save as expense'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final total = double.tryParse(_totalCtrl.text.replaceAll(',', ''));
    if (total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid total amount')),
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
    await context.read<TransactionProvider>().add(tx, items: _items.where((i) => i.itemName.trim().isNotEmpty).toList());
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
