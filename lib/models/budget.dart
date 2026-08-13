class Budget {
  const Budget({
    this.id,
    this.category,
    required this.month,
    required this.limitAmount,
  });

  final int? id;
  final String? category; // null = overall monthly budget
  final String month; // yyyy-MM
  final double limitAmount;

  bool get isOverall => category == null || category!.isEmpty;

  Budget copyWith({
    int? id,
    String? category,
    String? month,
    double? limitAmount,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      month: month ?? this.month,
      limitAmount: limitAmount ?? this.limitAmount,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'category': category,
        'month': month,
        'limit_amount': limitAmount,
      };

  factory Budget.fromMap(Map<String, Object?> map) {
    return Budget(
      id: map['id'] as int?,
      category: map['category'] as String?,
      month: map['month'] as String,
      limitAmount: (map['limit_amount'] as num).toDouble(),
    );
  }
}
