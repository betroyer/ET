class ReceiptItem {
  const ReceiptItem({
    this.id,
    this.transactionId,
    required this.itemName,
    required this.price,
    this.quantity = 1,
  });

  final int? id;
  final int? transactionId;
  final String itemName;
  final double price;
  final int quantity;

  double get lineTotal => price * quantity;

  ReceiptItem copyWith({
    int? id,
    int? transactionId,
    String? itemName,
    double? price,
    int? quantity,
  }) {
    return ReceiptItem(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      itemName: itemName ?? this.itemName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'item_name': itemName,
        'price': price,
        'quantity': quantity,
      };

  factory ReceiptItem.fromMap(Map<String, Object?> map) {
    return ReceiptItem(
      id: map['id'] as int?,
      transactionId: map['transaction_id'] as int?,
      itemName: map['item_name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int? ?? 1,
    );
  }
}
