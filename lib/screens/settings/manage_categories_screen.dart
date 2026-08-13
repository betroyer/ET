import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/category_provider.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final expense = provider.byType('expense');
    final income = provider.byType('income');

    return Scaffold(
      appBar: AppBar(title: const Text('Manage categories')),
      body: ListView(
        children: [
          const ListTile(title: Text('Expense', style: TextStyle(fontWeight: FontWeight.w700))),
          ...expense.map((c) => ListTile(
                leading: Text(c.icon, style: const TextStyle(fontSize: 22)),
                title: Text(c.name),
                subtitle: Text(c.isDefault ? 'Default' : 'Custom'),
                trailing: c.isDefault
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => context.read<CategoryProvider>().remove(c.id!),
                      ),
              )),
          const Divider(),
          const ListTile(title: Text('Income', style: TextStyle(fontWeight: FontWeight.w700))),
          ...income.map((c) => ListTile(
                leading: Text(c.icon, style: const TextStyle(fontSize: 22)),
                title: Text(c.name),
                subtitle: Text(c.isDefault ? 'Default' : 'Custom'),
                trailing: c.isDefault
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => context.read<CategoryProvider>().remove(c.id!),
                      ),
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController(text: '✨');
    var type = 'expense';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setState(() => type = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty && context.mounted) {
      await context.read<CategoryProvider>().addCustom(
            name: nameCtrl.text.trim(),
            icon: iconCtrl.text.trim().isEmpty ? '✨' : iconCtrl.text.trim(),
            type: type,
          );
    }
  }
}
