import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String displayDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  static String displayTime(DateTime date) => DateFormat('h:mm a').format(date);

  static String displayDateTime(DateTime date) =>
      DateFormat('MMM d, yyyy · h:mm a').format(date);

  static String isoDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  static String isoTime(DateTime date) => DateFormat('HH:mm:ss').format(date);

  static String monthKey(DateTime date) => DateFormat('yyyy-MM').format(date);

  static String friendly(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return DateFormat('EEEE').format(date);
    return displayDate(date);
  }
}
