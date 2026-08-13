import 'package:flutter/foundation.dart';

import '../models/receipt_item.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/date_formatter.dart';

class TransactionProvider extends ChangeNotifier {
  TransactionProvider(this._db, {NotificationService? notifications})
      : _notifications = notifications ?? NotificationService();

  final DatabaseService _db;
  final NotificationService _notifications;

  List<TransactionModel> _transactions = [];
  bool _loading = false;
  String? _error;

  List<TransactionModel> get transactions => _transactions;
  bool get loading => _loading;
  String? get error => _error;

  List<TransactionModel> get recent => _transactions.take(10).toList();

  double get totalIncome =>
      _transactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);

  double get totalExpenses =>
      _transactions.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);

  double get balance => totalIncome - totalExpenses;

  double get todayExpenses {
    final today = DateFormatter.isoDate(DateTime.now());
    return _transactions
        .where((t) => t.isExpense && t.date == today)
        .fold(0.0, (s, t) => s + t.amount);
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _transactions = await _db.getTransactions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<int> add(TransactionModel tx, {List<ReceiptItem> items = const []}) async {
    final id = await _db.insertTransaction(tx, items: items);
    await load();
    await _maybeBudgetAlert();
    return id;
  }

  Future<void> update(TransactionModel tx, {List<ReceiptItem>? items}) async {
    await _db.updateTransaction(tx, items: items);
    await load();
    await _maybeBudgetAlert();
  }

  Future<void> remove(int id) async {
    await _db.deleteTransaction(id);
    await load();
  }

  Future<List<TransactionModel>> forPeriod({
    required DateTime start,
    required DateTime end,
    String? type,
    String? category,
  }) {
    return _db.getTransactions(
      type: type,
      category: category,
      startDate: DateFormatter.isoDate(start),
      endDate: DateFormatter.isoDate(end),
    );
  }

  Future<Map<String, double>> categoryBreakdown({
    required DateTime start,
    required DateTime end,
  }) {
    return _db.sumByCategory(
      type: 'expense',
      startDate: DateFormatter.isoDate(start),
      endDate: DateFormatter.isoDate(end),
    );
  }

  Future<void> _maybeBudgetAlert() async {
    try {
      final month = DateFormatter.monthKey(DateTime.now());
      final budget = await _db.getOverallBudget(month);
      if (budget == null || budget.limitAmount <= 0) return;

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0);
      final spent = await _db.sumByType(
        type: 'expense',
        startDate: DateFormatter.isoDate(start),
        endDate: DateFormatter.isoDate(end),
      );

      final ratio = spent / budget.limitAmount;
      if (ratio >= 1) {
        await _notifications.showBudgetAlert(
          title: 'Budget exceeded',
          body: 'You have spent over your monthly budget.',
        );
      } else if (ratio >= 0.8) {
        await _notifications.showBudgetAlert(
          title: 'Budget almost reached',
          body: 'You have used ${(ratio * 100).toStringAsFixed(0)}% of your monthly budget.',
        );
      }
    } catch (_) {
      // Notifications are best-effort.
    }
  }
}
