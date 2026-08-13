import 'package:intl/intl.dart';

import 'constants.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(
    double amount, {
    String symbol = AppConstants.defaultCurrencySymbol,
  }) {
    final body = NumberFormat('#,##0.00', 'en_US').format(amount);
    return '$symbol$body';
  }

  static String compact(double amount, {String symbol = AppConstants.defaultCurrencySymbol}) {
    if (amount.abs() >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount.abs() >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, symbol: symbol);
  }
}
