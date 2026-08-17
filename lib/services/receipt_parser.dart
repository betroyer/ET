import 'ocr_service.dart';
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
  static final _moneyRe = RegExp(
    r'(?:PHP|Php|php|₱|P)?\s*'
    r'([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{2})|[0-9]+\.[0-9]{2})',
  );
  static final _totalRe = RegExp(
    r'\b(total|amount\s*due|grand\s*total|net\s*sales|amount\s*payable|balance\s*due)\b',
    caseSensitive: false,
  );
  static final _cashRe = RegExp(
    r'\b(cash|tender(?:ed)?|amount\s*received|paid|payment)\b',
    caseSensitive: false,
  );
  static final _changeRe = RegExp(r'\b(change|sukli)\b', caseSensitive: false);
  static final _skipRe = RegExp(
    r'\b(vat|vatable|tax|subtotal|sub\s*total|discount|or\s*no|tin|cashier|thank|welcome|'
    r'receipt|invoice|terminal|ref\s*no|txn|transaction|customer|points|promo)\b',
    caseSensitive: false,
  );

  /// Prefer structured OCR rows (geometry-aware). Falls back to plain text.
  ParsedReceipt parseOcr(OcrResult ocr) {
    if (ocr.lines.isNotEmpty) {
      return _parseLines(ocr.lines, fallbackText: ocr.rawText);
    }
    return parse(ocr.rawText);
  }

  /// Heuristic parser for typical PH supermarket / retail receipts (plain text).
  ParsedReceipt parse(String text, {List<({String text, double y, double x})>? blocks}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map(
          (l) => OcrLine(
            text: l,
            tokens: [OcrToken(text: l, left: 0, top: 0, right: 100, bottom: 18)],
            top: 0,
            bottom: 18,
          ),
        )
        .toList();
    return _parseLines(lines, fallbackText: text);
  }

  ParsedReceipt _parseLines(List<OcrLine> lines, {required String fallbackText}) {
    final items = <ReceiptItem>[];
    double? total;
    double? cash;
    double? change;

    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;

      if (_totalRe.hasMatch(text)) {
        total = _extractPrice(line) ?? _lastMoney(text) ?? total;
        continue;
      }
      if (_cashRe.hasMatch(text) && !_changeRe.hasMatch(text)) {
        cash = _extractPrice(line) ?? _lastMoney(text) ?? cash;
        continue;
      }
      if (_changeRe.hasMatch(text)) {
        change = _extractPrice(line) ?? _lastMoney(text) ?? change;
        continue;
      }
      if (_skipRe.hasMatch(text)) continue;

      final item = _itemFromLine(line);
      if (item != null) {
        items.add(item);
      }
    }

    // Deduplicate near-identical consecutive OCR duplicates.
    final cleaned = <ReceiptItem>[];
    for (final item in items) {
      if (cleaned.isNotEmpty) {
        final prev = cleaned.last;
        if (prev.itemName.toLowerCase() == item.itemName.toLowerCase() &&
            (prev.price - item.price).abs() < 0.009) {
          continue;
        }
      }
      cleaned.add(item);
    }

    total ??= cleaned.isEmpty ? null : cleaned.fold<double>(0, (s, i) => s + i.lineTotal);

    if (cash != null && total != null && change == null && cash >= total) {
      change = cash - total;
    }

    return ParsedReceipt(
      items: cleaned,
      total: total,
      cashTendered: cash,
      change: change,
      rawText: fallbackText,
    );
  }

  /// Match product name (left side of the row) with its price (rightmost money).
  ReceiptItem? _itemFromLine(OcrLine line) {
    final price = _extractPrice(line) ?? _lastMoney(line.text);
    if (price == null || price <= 0) return null;

    var name = _extractName(line);
    name = _cleanName(name);
    if (name.length < 2) return null;
    if (RegExp(r'^\d+([.,]\d+)?$').hasMatch(name)) return null;

    var qty = 1;
    final qtyMatch = RegExp(r'^(\d+)\s*[xX×]\s*(.+)$').firstMatch(name);
    if (qtyMatch != null) {
      qty = int.tryParse(qtyMatch.group(1)!) ?? 1;
      name = qtyMatch.group(2)!.trim();
    } else {
      // Patterns like "ITEM NAME  2  50.00" — qty token before price.
      final inlineQty = RegExp(r'^(.*?)(?:\s+)(\d{1,3})\s*$').firstMatch(name);
      if (inlineQty != null) {
        final maybeQty = int.tryParse(inlineQty.group(2)!);
        final left = inlineQty.group(1)!.trim();
        if (maybeQty != null && maybeQty > 1 && maybeQty <= 99 && left.length >= 2) {
          qty = maybeQty;
          name = left;
        }
      }
    }

    name = _cleanName(name);
    if (name.length < 2) return null;

    return ReceiptItem(itemName: name, price: price, quantity: qty);
  }

  /// Prefer the rightmost money-looking token on the row (typical receipt layout).
  double? _extractPrice(OcrLine line) {
    if (line.tokens.length >= 2) {
      final moneyTokens = line.tokens.where((t) => _isMoneyToken(t.text)).toList();
      if (moneyTokens.isNotEmpty) {
        // Rightmost money token = line price.
        moneyTokens.sort((a, b) => a.left.compareTo(b.left));
        return _parseMoney(moneyTokens.last.text);
      }
    }
    return _lastMoney(line.text);
  }

  /// Product name = tokens to the left of the price token, joined in order.
  String _extractName(OcrLine line) {
    if (line.tokens.length >= 2) {
      final moneyIndexes = <int>[];
      for (var i = 0; i < line.tokens.length; i++) {
        if (_isMoneyToken(line.tokens[i].text)) moneyIndexes.add(i);
      }
      if (moneyIndexes.isNotEmpty) {
        final priceIndex = moneyIndexes.last;
        final nameTokens = line.tokens.take(priceIndex).where((t) {
          final s = t.text.trim();
          if (s.isEmpty) return false;
          if (_isMoneyToken(s)) return false;
          // Drop solitary currency markers.
          if (RegExp(r'^(PHP|Php|₱|P)$').hasMatch(s)) return false;
          return true;
        }).map((t) => t.text.trim());
        final joined = nameTokens.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        if (joined.isNotEmpty) return joined;
      }
    }

    // Plain-text fallback: everything before the last money match.
    final matches = _moneyRe.allMatches(line.text).toList();
    if (matches.isEmpty) return line.text;
    return line.text.substring(0, matches.last.start).trim();
  }

  bool _isMoneyToken(String raw) {
    final t = raw.trim().replaceAll(',', '');
    if (RegExp(r'^(PHP|Php|₱|P)$').hasMatch(t)) return false;
    // 12.50 / 1,250.00 / PHP12.50 / ₱12.50
    if (_moneyRe.hasMatch(raw)) {
      // Avoid treating bare integers that look like qty/codes as money
      // unless they have decimals or currency markers.
      final hasDecimal = raw.contains('.');
      final hasCurrency = RegExp(r'(PHP|Php|₱|P)', caseSensitive: false).hasMatch(raw);
      if (hasDecimal || hasCurrency) return true;
      // Large whole numbers on receipts can still be pesos without decimals.
      final n = double.tryParse(t.replaceAll(RegExp(r'[^0-9.]'), ''));
      return n != null && n >= 10;
    }
    return false;
  }

  double? _lastMoney(String line) {
    final matches = _moneyRe.allMatches(line).toList();
    if (matches.isEmpty) return null;
    return _parseMoney(matches.last.group(0)!);
  }

  double? _parseMoney(String raw) {
    final m = _moneyRe.firstMatch(raw);
    final body = (m?.group(1) ?? raw).replaceAll(',', '').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(body);
  }

  String _cleanName(String name) {
    var n = name.trim();
    n = n.replaceAll(RegExp(r'[.\-_|]+$'), '').trim();
    n = n.replaceAll(RegExp(r'^[\-_|.\s]+'), '').trim();
    n = n.replaceAll(RegExp(r'\s+'), ' ');
    // Strip trailing qty markers left behind: "ITEM x" / "ITEM *"
    n = n.replaceAll(RegExp(r'[\sxX×*]+$'), '').trim();
    return n;
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
}
