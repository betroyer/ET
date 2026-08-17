import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:math' as math;

/// One OCR text element with page coordinates for row matching.
class OcrToken {
  const OcrToken({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerY => (top + bottom) / 2;
  double get centerX => (left + right) / 2;
  double get height => math.max(1, bottom - top);
}

/// A reconstructed receipt row (left-to-right text on roughly the same Y).
class OcrLine {
  const OcrLine({
    required this.text,
    required this.tokens,
    required this.top,
    required this.bottom,
  });

  final String text;
  final List<OcrToken> tokens;
  final double top;
  final double bottom;

  double get centerY => (top + bottom) / 2;
}

class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.lines,
    required this.tokens,
  });

  final String rawText;
  final List<OcrLine> lines;
  final List<OcrToken> tokens;
}

class OcrService {
  OcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Runs OCR and rebuilds receipt rows using bounding-box Y positions so
  /// product names and prices on the same printed line stay paired.
  Future<OcrResult> recognizeStructured(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);
    return _toStructured(recognized);
  }

  Future<RecognizedText> recognizeFromPath(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    return _recognizer.processImage(input);
  }

  Future<RecognizedText> recognizeFromFile(File file) {
    return recognizeFromPath(file.path);
  }

  OcrResult _toStructured(RecognizedText recognized) {
    final tokens = <OcrToken>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        if (line.elements.isNotEmpty) {
          for (final el in line.elements) {
            final box = el.boundingBox;
            final text = el.text.trim();
            if (text.isEmpty) continue;
            tokens.add(
              OcrToken(
                text: text,
                left: box.left.toDouble(),
                top: box.top.toDouble(),
                right: box.right.toDouble(),
                bottom: box.bottom.toDouble(),
              ),
            );
          }
        } else {
          final box = line.boundingBox;
          final text = line.text.trim();
          if (text.isEmpty) continue;
          tokens.add(
            OcrToken(
              text: text,
              left: box.left.toDouble(),
              top: box.top.toDouble(),
              right: box.right.toDouble(),
              bottom: box.bottom.toDouble(),
            ),
          );
        }
      }
    }

    if (tokens.isEmpty) {
      final plainLines = recognized.text
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final lines = <OcrLine>[
        for (var i = 0; i < plainLines.length; i++)
          OcrLine(
            text: plainLines[i],
            tokens: [
              OcrToken(
                text: plainLines[i],
                left: 0,
                top: i * 20.0,
                right: 100,
                bottom: i * 20.0 + 18,
              ),
            ],
            top: i * 20.0,
            bottom: i * 20.0 + 18,
          ),
      ];
      return OcrResult(rawText: recognized.text, lines: lines, tokens: const []);
    }

    final lines = _clusterIntoRows(tokens);
    final raw = lines.map((l) => l.text).join('\n');
    return OcrResult(
      rawText: raw.isEmpty ? recognized.text : raw,
      lines: lines,
      tokens: tokens,
    );
  }

  /// Groups tokens that share roughly the same vertical center into one row,
  /// then sorts each row left → right so "NAME ..... PRICE" stays aligned.
  List<OcrLine> _clusterIntoRows(List<OcrToken> tokens) {
    final sorted = [...tokens]..sort((a, b) {
        final dy = a.centerY.compareTo(b.centerY);
        if (dy != 0) return dy;
        return a.left.compareTo(b.left);
      });

    final rows = <List<OcrToken>>[];
    for (final token in sorted) {
      if (rows.isEmpty) {
        rows.add([token]);
        continue;
      }
      final row = rows.last;
      final avgHeight = row.map((t) => t.height).reduce((a, b) => a + b) / row.length;
      final avgY = row.map((t) => t.centerY).reduce((a, b) => a + b) / row.length;
      final threshold = math.max(12.0, avgHeight * 0.7);
      if ((token.centerY - avgY).abs() <= threshold) {
        row.add(token);
      } else {
        rows.add([token]);
      }
    }

    return rows.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      final text = row.map((t) => t.text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final top = row.map((t) => t.top).reduce(math.min);
      final bottom = row.map((t) => t.bottom).reduce(math.max);
      return OcrLine(text: text, tokens: List.unmodifiable(row), top: top, bottom: bottom);
    }).toList();
  }

  Future<void> dispose() => _recognizer.close();
}
