import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  OcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  Future<RecognizedText> recognizeFromPath(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    return _recognizer.processImage(input);
  }

  Future<RecognizedText> recognizeFromFile(File file) {
    return recognizeFromPath(file.path);
  }

  Future<void> dispose() => _recognizer.close();
}
