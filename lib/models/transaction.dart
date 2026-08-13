import 'receipt_item.dart';

class TransactionModel {
  const TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.source,
    required this.date,
    required this.time,
    this.paymentMethod,
    this.note,
    this.receiptImagePath,
    this.createdAt,
    this.items = const [],
  });

  final int? id;
  final String type; // expense | income
  final double amount;
  final String category;
  final String? source;
  final String date; // yyyy-MM-dd
  final String time; // HH:mm:ss
  final String? paymentMethod;
  final String? note;
  final String? receiptImagePath;
  final String? createdAt;
  final List<ReceiptItem> items;

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';

  DateTime get dateTime {
    try {
      return DateTime.parse('${date}T$time');
    } catch (_) {
      return DateTime.tryParse(date) ?? DateTime.now();
    }
  }

  TransactionModel copyWith({
    int? id,
    String? type,
    double? amount,
    String? category,
    String? source,
    String? date,
    String? time,
    String? paymentMethod,
    String? note,
    String? receiptImagePath,
    String? createdAt,
    List<ReceiptItem>? items,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      source: source ?? this.source,
      date: date ?? this.date,
      time: time ?? this.time,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'category': category,
        'source': source,
        'date': date,
        'time': time,
        'payment_method': paymentMethod,
        'note': note,
        'receipt_image_path': receiptImagePath,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, Object?> map, {List<ReceiptItem> items = const []}) {
    return TransactionModel(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String,
      source: map['source'] as String?,
      date: map['date'] as String,
      time: map['time'] as String,
      paymentMethod: map['payment_method'] as String?,
      note: map['note'] as String?,
      receiptImagePath: map['receipt_image_path'] as String?,
      createdAt: map['created_at'] as String?,
      items: items,
    );
  }
}
