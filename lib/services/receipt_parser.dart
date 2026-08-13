import '../models/receipt_item.dart';

class ParsedReceipt {
  ParsedReceipt({
    this.items = const [],
    this.total,
    this.cashTendered,
    this.change,
    this.rawText = '',
    this.reference,
  });

  final List<ReceiptItem> items;
  final double? total;
  final double? cashTendered;
  final double? change;
  final String rawText;
  final String? reference;

  ParsedReceipt copyWith({
    List<ReceiptItem>? items,
    double? total,
    double? cashTendered,
    double? change,
    String? rawText,
    String? reference,
  }) {
    return ParsedReceipt(
      items: items ?? this.items,
      total: total ?? this.total,
      cashTendered: cashTendered ?? this.cashTendered,
      change: change ?? this.change,
      rawText: rawText ?? this.rawText,
      reference: reference ?? this.reference,
    );
  }
}

class ReceiptParser {
  /// Heuristic parser for typical PH supermarket / retail receipts.
  ParsedReceipt parse(String text, {List<({String text, double y, double x})>? blocks}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final items = <ReceiptItem>[];
    double? total;
    double? cash;
    double? change;

    final moneyRe = RegExp(
      r'(?:PHP|Php|php|₱|P)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})|[0-9]+\.[0-9]{2}|[0-9]+)',
    );
    final totalRe = RegExp(r'\b(total|amount\s*due|grand\s*total|net\s*sales)\b', caseSensitive: false);
    final cashRe = RegExp(r'\b(cash|tender(?:ed)?|amount\s*received|paid)\b', caseSensitive: false);
    final changeRe = RegExp(r'\b(change|sukli)\b', caseSensitive: false);
    final skipRe = RegExp(
      r'\b(vat|vatable|tax|subtotal|sub\s*total|discount|or\s*no|tin|cashier|thank|welcome|receipt)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (totalRe.hasMatch(line)) {
        total = _lastMoney(line, moneyRe) ?? total;
        continue;
      }
      if (cashRe.hasMatch(line) && !changeRe.hasMatch(line)) {
        cash = _lastMoney(line, moneyRe) ?? cash;
        continue;
      }
      if (changeRe.hasMatch(line)) {
        change = _lastMoney(line, moneyRe) ?? change;
        continue;
      }
      if (skipRe.hasMatch(line)) continue;

      final moneyMatch = moneyRe.allMatches(line).toList();
      if (moneyMatch.isEmpty) continue;

      final price = double.tryParse(moneyMatch.last.group(1)!.replaceAll(',', ''));
      if (price == null || price <= 0) continue;

      var name = line.substring(0, moneyMatch.last.start).trim();
      name = name.replaceAll(RegExp(r'[.\-]+$'), '').trim();
      if (name.length < 2) continue;
      if (RegExp(r'^\d+$').hasMatch(name)) continue;

      // Quantity patterns like "2 x Item 50.00" or "Item x2 50.00"
      var qty = 1;
      final qtyMatch = RegExp(r'^(\d+)\s*[xX]\s*(.+)$').firstMatch(name);
      if (qtyMatch != null) {
        qty = int.tryParse(qtyMatch.group(1)!) ?? 1;
        name = qtyMatch.group(2)!.trim();
      }

      items.add(ReceiptItem(itemName: name, price: price, quantity: qty));
    }

    // If no explicit total, sum items.
    total ??= items.isEmpty ? null : items.fold<double>(0, (s, i) => s + i.lineTotal);

    if (cash != null && total != null && change == null && cash >= total) {
      change = cash - total;
    }

    return ParsedReceipt(
      items: items,
      total: total,
      cashTendered: cash,
      change: change,
      rawText: text,
    );
  }

  ParsedReceipt parseFromQrPayload(String payload) {
    final uri = Uri.tryParse(payload);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return ParsedReceipt(
        rawText: payload,
        reference: payload,
        total: null,
      );
    }

    // BIR / generic key-value style payloads
    final amountMatch = RegExp(
      r'(?:amount|total|amt)[=:]\s*([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(payload);
    final refMatch = RegExp(
      r'(?:ref|invoice|or|tin)[=:#]\s*([A-Za-z0-9\-]+)',
      caseSensitive: false,
    ).firstMatch(payload);

    return ParsedReceipt(
      rawText: payload,
      total: amountMatch != null ? double.tryParse(amountMatch.group(1)!) : null,
      reference: refMatch?.group(1) ?? (payload.length > 80 ? '${payload.substring(0, 80)}…' : payload),
    );
  }

  double? _lastMoney(String line, RegExp moneyRe) {
    final matches = moneyRe.allMatches(line).toList();
    if (matches.isEmpty) return null;
    return double.tryParse(matches.last.group(1)!.replaceAll(',', ''));
  }
}
