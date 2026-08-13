import 'package:flutter/material.dart';

class AppConstants {
  static const appName = 'Expense Tracker';
  static const defaultCurrencyCode = 'PHP';
  static const defaultCurrencySymbol = '₱';

  static const paymentMethods = [
    'Cash',
    'GCash',
    'Maya',
    'Card',
    'Bank Transfer',
    'Other',
  ];

  static const incomeSources = [
    'Salary',
    'Allowance',
    'Freelance',
    'Business',
    'Gift',
    'Other',
  ];

  static const defaultExpenseCategories = [
    ('Food', '🍔'),
    ('Transportation', '🚌'),
    ('Housing', '🏠'),
    ('Bills', '💡'),
    ('Shopping', '🛒'),
    ('Entertainment', '🎮'),
    ('Health', '💊'),
    ('Education', '📚'),
    ('Communication', '📱'),
    ('Others', '📦'),
  ];

  static const defaultIncomeCategories = [
    ('Salary', '💼'),
    ('Allowance', '🎁'),
    ('Freelance', '💻'),
    ('Business', '🏪'),
    ('Gift', '🎀'),
    ('Other', '💰'),
  ];

  static const brandTeal = Color(0xFF0F766E);
  static const brandTealDark = Color(0xFF115E59);
  static const brandMint = Color(0xFF14B8A6);
  static const brandCoral = Color(0xFFE11D48);
  static const brandAmber = Color(0xFFD97706);
  static const brandSurface = Color(0xFFF3F7F6);
  static const brandInk = Color(0xFF0F172A);
}