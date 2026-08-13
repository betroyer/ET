import 'package:flutter/foundation.dart';

import '../models/category.dart';
import '../services/database_service.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._db);

  final DatabaseService _db;

  List<CategoryModel> _categories = [];
  bool _loading = false;

  List<CategoryModel> get categories => _categories;
  bool get loading => _loading;

  List<CategoryModel> byType(String type) =>
      _categories.where((c) => c.type == type).toList();

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _categories = await _db.getCategories();
    _loading = false;
    notifyListeners();
  }

  Future<void> addCustom({
    required String name,
    required String icon,
    required String type,
  }) async {
    await _db.insertCategory(
      CategoryModel(name: name, icon: icon, type: type, isDefault: false),
    );
    await load();
  }

  Future<void> update(CategoryModel category) async {
    await _db.updateCategory(category);
    await load();
  }

  Future<void> remove(int id) async {
    await _db.deleteCategory(id);
    await load();
  }

  String iconFor(String name, {String fallback = '📦'}) {
    for (final c in _categories) {
      if (c.name == name) return c.icon;
    }
    return fallback;
  }
}
