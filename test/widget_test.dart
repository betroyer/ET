import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/receipt_parser.dart';

void main() {
  test('ReceiptParser extracts total and items', () {
    const text = '''
SUPERMARKET
Milk 85.00
Bread 45.50
TOTAL 130.50
CASH 200.00
CHANGE 69.50
''';
    final parsed = ReceiptParser().parse(text);
    expect(parsed.total, 130.50);
    expect(parsed.cashTendered, 200.00);
    expect(parsed.change, 69.50);
    expect(parsed.items.length, greaterThanOrEqualTo(2));
  });
}
