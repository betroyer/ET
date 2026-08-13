import 'package:flutter/foundation.dart';

import '../models/budget.dart';
import '../services/database_service.dart';
import '../utils/date_formatter.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider(this._db);

  final DatabaseService _db;

  List<Budget> _budgets = [];
  bool _loading = false;

  List<Budget> get budgets => _budgets;
  bool get loading => _loading;

  Budget? get overall {
    try {
      return _budgets.firstWhere((b) => b.isOverall);
    } catch (_) {
      return null;
    }
  }

  Future<void> load([String? month]) async {
    _loading = true;
    notifyListeners();
    final key = month ?? DateFormatter.monthKey(DateTime.now());
    _budgets = await _db.getBudgets(month: key);
    _loading = false;
    notifyListeners();
  }

  Future<void> saveOverall(double limit, {String? month}) async {
    final key = month ?? DateFormatter.monthKey(DateTime.now());
    await _db.upsertBudget(Budget(month: key, limitAmount: limit));
    await load(key);
  }

  Future<void> saveCategory({
    required String category,
    required double limit,
    String? month,
  }) async {
    final key = month ?? DateFormatter.monthKey(DateTime.now());
    await _db.upsertBudget(
      Budget(category: category, month: key, limitAmount: limit),
    );
    await load(key);
  }

  Future<void> remove(int id) async {
    await _db.deleteBudget(id);
    await load();
  }

  Future<double> spentThisMonth() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return _db.sumByType(
      type: 'expense',
      startDate: DateFormatter.isoDate(start),
      endDate: DateFormatter.isoDate(end),
    );
  }
}
