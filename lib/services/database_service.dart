import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/budget.dart';
import '../models/category.dart';
import '../models/receipt_item.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'expense_tracker.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<String> get databasePath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbName);
  }

  Future<Database> _initDb() async {
    final path = await databasePath;
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        type TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        source TEXT,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        payment_method TEXT,
        note TEXT,
        receipt_image_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE receipt_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT,
        month TEXT NOT NULL,
        limit_amount REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final batch = db.batch();
    for (final (name, icon) in AppConstants.defaultExpenseCategories) {
      batch.insert('categories', {
        'name': name,
        'icon': icon,
        'type': 'expense',
        'is_default': 1,
      });
    }
    for (final (name, icon) in AppConstants.defaultIncomeCategories) {
      batch.insert('categories', {
        'name': name,
        'icon': icon,
        'type': 'income',
        'is_default': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  // --- Categories ---

  Future<List<CategoryModel>> getCategories({String? type}) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: type == null ? null : 'type = ?',
      whereArgs: type == null ? null : [type],
      orderBy: 'is_default DESC, name ASC',
    );
    return maps.map(CategoryModel.fromMap).toList();
  }

  Future<int> insertCategory(CategoryModel category) async {
    final db = await database;
    return db.insert('categories', category.toMap()..remove('id'));
  }

  Future<int> updateCategory(CategoryModel category) async {
    final db = await database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    final rows = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return 0;
    if ((rows.first['is_default'] as int? ?? 0) == 1) {
      throw StateError('Default categories cannot be deleted');
    }
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Transactions ---

  Future<List<TransactionModel>> getTransactions({
    String? type,
    String? category,
    String? startDate,
    String? endDate,
    int? limit,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <Object?>[];

    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    if (startDate != null) {
      where.add('date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      where.add('date <= ?');
      args.add(endDate);
    }

    final maps = await db.query(
      'transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, time DESC, id DESC',
      limit: limit,
    );

    final result = <TransactionModel>[];
    for (final map in maps) {
      final id = map['id'] as int;
      final items = await getReceiptItems(id);
      result.add(TransactionModel.fromMap(map, items: items));
    }
    return result;
  }

  Future<TransactionModel?> getTransaction(int id) async {
    final db = await database;
    final maps = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final items = await getReceiptItems(id);
    return TransactionModel.fromMap(maps.first, items: items);
  }

  Future<int> insertTransaction(TransactionModel tx, {List<ReceiptItem> items = const []}) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('transactions', tx.toMap()..remove('id'));
      for (final item in items) {
        await txn.insert(
          'receipt_items',
          item.copyWith(transactionId: id).toMap()..remove('id'),
        );
      }
      return id;
    });
  }

  Future<int> updateTransaction(TransactionModel tx, {List<ReceiptItem>? items}) async {
    final db = await database;
    return db.transaction((txn) async {
      final count = await txn.update(
        'transactions',
        tx.toMap(),
        where: 'id = ?',
        whereArgs: [tx.id],
      );
      if (items != null && tx.id != null) {
        await txn.delete('receipt_items', where: 'transaction_id = ?', whereArgs: [tx.id]);
        for (final item in items) {
          await txn.insert(
            'receipt_items',
            item.copyWith(transactionId: tx.id).toMap()..remove('id'),
          );
        }
      }
      return count;
    });
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ReceiptItem>> getReceiptItems(int transactionId) async {
    final db = await database;
    final maps = await db.query(
      'receipt_items',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );
    return maps.map(ReceiptItem.fromMap).toList();
  }

  Future<double> sumByType({
    required String type,
    String? startDate,
    String? endDate,
    String? category,
  }) async {
    final db = await database;
    final where = <String>['type = ?'];
    final args = <Object?>[type];
    if (startDate != null) {
      where.add('date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      where.add('date <= ?');
      args.add(endDate);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE ${where.join(' AND ')}',
      args,
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<Map<String, double>> sumByCategory({
    required String type,
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;
    final where = <String>['type = ?'];
    final args = <Object?>[type];
    if (startDate != null) {
      where.add('date >= ?');
      args.add(startDate);
    }
    if (endDate != null) {
      where.add('date <= ?');
      args.add(endDate);
    }
    final rows = await db.rawQuery(
      '''
      SELECT category, COALESCE(SUM(amount), 0) as total
      FROM transactions
      WHERE ${where.join(' AND ')}
      GROUP BY category
      ORDER BY total DESC
      ''',
      args,
    );
    return {
      for (final row in rows) row['category'] as String: (row['total'] as num).toDouble(),
    };
  }

  // --- Budgets ---

  Future<List<Budget>> getBudgets({String? month}) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: month == null ? null : 'month = ?',
      whereArgs: month == null ? null : [month],
      orderBy: 'category IS NOT NULL, category ASC',
    );
    return maps.map(Budget.fromMap).toList();
  }

  Future<Budget?> getOverallBudget(String month) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: 'month = ? AND (category IS NULL OR category = "")',
      whereArgs: [month],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<int> upsertBudget(Budget budget) async {
    final db = await database;
    final existing = await db.query(
      'budgets',
      where: budget.isOverall
          ? 'month = ? AND (category IS NULL OR category = "")'
          : 'month = ? AND category = ?',
      whereArgs: budget.isOverall ? [budget.month] : [budget.month, budget.category],
      limit: 1,
    );
    if (existing.isEmpty) {
      return db.insert('budgets', budget.toMap()..remove('id'));
    }
    final id = existing.first['id'] as int;
    await db.update(
      'budgets',
      budget.copyWith(id: id).toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // --- Settings key-value ---

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> exportJsonDump() async {
    final db = await database;
    return {
      'transactions': await db.query('transactions'),
      'receipt_items': await db.query('receipt_items'),
      'categories': await db.query('categories'),
      'budgets': await db.query('budgets'),
      'settings': await db.query('settings'),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importJsonDump(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('receipt_items');
      await txn.delete('transactions');
      await txn.delete('budgets');
      await txn.delete('categories');
      await txn.delete('settings');

      for (final row in (data['categories'] as List? ?? [])) {
        await txn.insert('categories', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['transactions'] as List? ?? [])) {
        await txn.insert('transactions', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['receipt_items'] as List? ?? [])) {
        await txn.insert('receipt_items', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['budgets'] as List? ?? [])) {
        await txn.insert('budgets', Map<String, Object?>.from(row as Map));
      }
      for (final row in (data['settings'] as List? ?? [])) {
        await txn.insert('settings', Map<String, Object?>.from(row as Map));
      }
    });
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    await db?.close();
  }
}
