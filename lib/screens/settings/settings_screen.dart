import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../providers/budget_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/backup_service.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import 'about_screen.dart';
import 'budget_settings_screen.dart';
import 'manage_categories_screen.dart';
import 'pin_lock_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Preferences'),
          SwitchListTile(
            title: const Text('Dark mode'),
            value: settings.darkMode,
            onChanged: (v) => context.read<SettingsProvider>().setDarkMode(v),
          ),
          ListTile(
            title: const Text('Currency'),
            subtitle: Text('${settings.currencyCode} (${settings.currencySymbol})'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickCurrency(context),
          ),
          const _SectionHeader('Money'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage categories'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Monthly budget'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BudgetSettingsScreen()),
            ),
          ),
          const _SectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: const Text('Remind me to log expenses at 8:00 PM'),
            value: settings.dailyReminder,
            onChanged: (v) => context.read<SettingsProvider>().setDailyReminder(v),
          ),
          SwitchListTile(
            title: const Text('Budget alerts'),
            subtitle: const Text('Notify when nearing or exceeding budget'),
            value: settings.budgetAlerts,
            onChanged: (v) => context.read<SettingsProvider>().setBudgetAlerts(v),
          ),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: const Text('Export CSV'),
            onTap: () => _exportCsv(context),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export PDF report'),
            onTap: () => _exportPdf(context),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup data'),
            onTap: () => _backup(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore backup'),
            onTap: () => _restore(context),
          ),
          const _SectionHeader('Security'),
          SwitchListTile(
            title: const Text('PIN lock'),
            subtitle: const Text('Require PIN when opening the app'),
            value: settings.pinEnabled,
            onChanged: (v) async {
              if (v) {
                final pin = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const PinLockScreen(mode: PinMode.setup),
                  ),
                );
                if (pin != null && context.mounted) {
                  await context.read<SettingsProvider>().enablePin(pin);
                }
              } else {
                await context.read<SettingsProvider>().disablePin();
              }
            },
          ),
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context) async {
    const options = [
      ('PHP', '₱'),
      ('USD', '\$'),
      ('EUR', '€'),
      ('JPY', '¥'),
      ('KRW', '₩'),
    ];
    final selected = await showModalBottomSheet<(String, String)>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (o) => ListTile(
                  title: Text('${o.$1} (${o.$2})'),
                  onTap: () => Navigator.pop(context, o),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null && context.mounted) {
      await context.read<SettingsProvider>().setCurrency(code: selected.$1, symbol: selected.$2);
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    final tx = context.read<TransactionProvider>().transactions;
    final export = ExportService();
    final file = await export.exportCsv(tx);
    await export.shareFile(file);
  }

  Future<void> _exportPdf(BuildContext context) async {
    final provider = context.read<TransactionProvider>();
    final export = ExportService();
    final file = await export.exportPdf(
      transactions: provider.transactions,
      income: provider.totalIncome,
      expenses: provider.totalExpenses,
    );
    await export.shareFile(file);
  }

  Future<void> _backup(BuildContext context) async {
    final backup = BackupService(DatabaseService.instance);
    await backup.shareBackup();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup ready to share')),
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final backup = BackupService(DatabaseService.instance);
    final files = await backup.listBackupFiles();
    if (!context.mounted) return;

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local backups found. Create a backup first.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<File>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a backup', style: TextStyle(fontWeight: FontWeight.w700))),
            ...files.map(
              (f) => ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: Text(p.basename(f.path)),
                onTap: () => Navigator.pop(context, f),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text('This will replace current data with the selected backup file.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final restored = await backup.restoreFromFile(selected);
      if (!restored || !context.mounted) return;
      await Future.wait([
        context.read<TransactionProvider>().load(),
        context.read<BudgetProvider>().load(),
      ]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
