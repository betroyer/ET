import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/ocr_service.dart';
import 'package:my_app/services/receipt_parser.dart';

void main() {
  test('ReceiptParser extracts total and items from plain text', () {
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
    expect(parsed.items.any((i) => i.itemName.contains('Milk') && i.price == 85.00), isTrue);
    expect(parsed.items.any((i) => i.itemName.contains('Bread') && i.price == 45.50), isTrue);
  });

  test('parseOcr matches left-side names with right-side prices per row', () {
    final lines = [
      OcrLine(
        text: 'Pancit Canton 18.50',
        tokens: const [
          OcrToken(text: 'Pancit', left: 10, top: 40, right: 70, bottom: 58),
          OcrToken(text: 'Canton', left: 75, top: 40, right: 140, bottom: 58),
          OcrToken(text: '18.50', left: 220, top: 40, right: 270, bottom: 58),
        ],
        top: 40,
        bottom: 58,
      ),
      OcrLine(
        text: 'Soft Drink 25.00',
        tokens: const [
          OcrToken(text: 'Soft', left: 10, top: 70, right: 50, bottom: 88),
          OcrToken(text: 'Drink', left: 55, top: 70, right: 110, bottom: 88),
          OcrToken(text: '25.00', left: 220, top: 70, right: 270, bottom: 88),
        ],
        top: 70,
        bottom: 88,
      ),
      OcrLine(
        text: 'TOTAL 43.50',
        tokens: const [
          OcrToken(text: 'TOTAL', left: 10, top: 110, right: 70, bottom: 128),
          OcrToken(text: '43.50', left: 220, top: 110, right: 270, bottom: 128),
        ],
        top: 110,
        bottom: 128,
      ),
    ];

    final parsed = ReceiptParser().parseOcr(
      OcrResult(
        rawText: lines.map((l) => l.text).join('\n'),
        lines: lines,
        tokens: const [],
      ),
    );

    expect(parsed.items.length, 2);
    expect(parsed.items[0].itemName, 'Pancit Canton');
    expect(parsed.items[0].price, 18.50);
    expect(parsed.items[1].itemName, 'Soft Drink');
    expect(parsed.items[1].price, 25.00);
    expect(parsed.total, 43.50);
  });

  test('quantity pattern 2 x Item is parsed', () {
    final parsed = ReceiptParser().parse('2 x Eggs 90.00\nTOTAL 90.00');
    expect(parsed.items, isNotEmpty);
    expect(parsed.items.first.quantity, 2);
    expect(parsed.items.first.itemName.toLowerCase(), contains('egg'));
    expect(parsed.items.first.price, 90.00);
  });
}
