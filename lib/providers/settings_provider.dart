import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    AuthService? auth,
    NotificationService? notifications,
  })  : _auth = auth ?? AuthService(),
        _notifications = notifications ?? NotificationService();

  final AuthService _auth;
  final NotificationService _notifications;

  SharedPreferences? _prefs;

  String currencyCode = AppConstants.defaultCurrencyCode;
  String currencySymbol = AppConstants.defaultCurrencySymbol;
  bool darkMode = false;
  bool dailyReminder = false;
  bool budgetAlerts = true;
  bool pinEnabled = false;
  bool unlocked = true;

  AuthService get auth => _auth;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    currencyCode = _prefs!.getString('currency_code') ?? AppConstants.defaultCurrencyCode;
    currencySymbol = _prefs!.getString('currency_symbol') ?? AppConstants.defaultCurrencySymbol;
    darkMode = _prefs!.getBool('dark_mode') ?? false;
    dailyReminder = _prefs!.getBool('daily_reminder') ?? false;
    budgetAlerts = _prefs!.getBool('budget_alerts') ?? true;
    pinEnabled = await _auth.isPinEnabled();
    unlocked = !pinEnabled;
    notifyListeners();

    if (dailyReminder) {
      await _notifications.scheduleDailyReminder(enabled: true);
    }
  }

  Future<void> setCurrency({required String code, required String symbol}) async {
    currencyCode = code;
    currencySymbol = symbol;
    await _prefs?.setString('currency_code', code);
    await _prefs?.setString('currency_symbol', symbol);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    await _prefs?.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setDailyReminder(bool value) async {
    dailyReminder = value;
    await _prefs?.setBool('daily_reminder', value);
    await _notifications.scheduleDailyReminder(enabled: value);
    notifyListeners();
  }

  Future<void> setBudgetAlerts(bool value) async {
    budgetAlerts = value;
    await _prefs?.setBool('budget_alerts', value);
    notifyListeners();
  }

  Future<void> enablePin(String pin) async {
    await _auth.setPin(pin);
    pinEnabled = true;
    unlocked = true;
    notifyListeners();
  }

  Future<void> disablePin() async {
    await _auth.disablePin();
    pinEnabled = false;
    unlocked = true;
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    final ok = await _auth.verifyPin(pin);
    unlocked = ok;
    notifyListeners();
    return ok;
  }

  void lock() {
    if (pinEnabled) {
      unlocked = false;
      notifyListeners();
    }
  }
}
