import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ocr_service.dart';
import '../../services/receipt_parser.dart';
import 'review_receipt_screen.dart';

/// Receipt photo scanner (OCR). Captures a receipt image, extracts line items
/// and totals, then opens the review screen with those expenses filled in.
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  bool _busy = false;
  String? _status;
  final _ocr = OcrService();
  final _parser = ReceiptParser();

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(Icons.document_scanner_outlined, size: 48, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Scan a receipt',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take a photo of your receipt. ExTra will read the items and amounts, then show them as an expense for you to confirm.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _busy ? null : () => _capture(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Scan with camera'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _capture(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Choose receipt photo'),
              ),
            ),
            const SizedBox(height: 28),
            if (_busy) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                _status ?? 'Reading receipt…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Extracting items and totals…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
            const Spacer(),
            Text(
              'Tip: Lay the receipt flat with good lighting so item names and prices are clear.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capture(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 95,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (file == null) return;

    setState(() {
      _busy = true;
      _status = 'Scanning receipt…';
    });

    try {
      final recognized = await _ocr.recognizeFromPath(file.path);
      setState(() => _status = 'Finding expenses…');
      final parsed = _parser.parse(recognized.text);

      if (!mounted) return;

      // Automatically open the expense review with extracted receipt data.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewReceiptScreen(
            parsed: parsed,
            imagePath: file.path,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read receipt: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
