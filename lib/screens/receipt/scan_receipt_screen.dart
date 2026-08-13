import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/ocr_service.dart';
import '../../services/qr_service.dart';
import '../../services/receipt_parser.dart';
import 'review_receipt_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _busy = false;
  String? _status;
  final _ocr = OcrService();
  final _parser = ReceiptParser();
  final _qr = QrService();
  bool _handledQr = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.text_snippet_outlined), text: 'OCR'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OcrTab(
            busy: _busy,
            status: _status,
            onCamera: () => _capture(ImageSource.camera),
            onGallery: () => _capture(ImageSource.gallery),
          ),
          _QrTab(
            onDetect: _onQr,
            busy: _busy,
          ),
        ],
      ),
    );
  }

  Future<void> _capture(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null) return;

    setState(() {
      _busy = true;
      _status = 'Reading receipt…';
    });

    try {
      final recognized = await _ocr.recognizeFromPath(file.path);
      final parsed = _parser.parse(recognized.text);
      if (!mounted) return;
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
      setState(() => _status = 'OCR failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read receipt: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onQr(BarcodeCapture capture) async {
    if (_handledQr || _busy) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _handledQr = true;
    setState(() {
      _busy = true;
      _status = 'Decoding QR…';
    });

    try {
      var parsed = _parser.parseFromQrPayload(raw);
      if (_qr.looksLikeUrl(raw)) {
        // Many PH digital receipt URLs are auth-gated; keep URL as reference.
        parsed = parsed.copyWith(
          reference: raw,
          rawText: 'QR URL detected. Fill amount manually or use OCR for itemized receipts.\n$raw',
        );
      } else if (_qr.looksLikeBirPayload(raw)) {
        parsed = parsed.copyWith(
          rawText:
              'BIR / invoice QR detected. Item prices are usually not included — enter amount manually or switch to OCR.\n$raw',
        );
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewReceiptScreen(parsed: parsed),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _handledQr = false;
        });
      }
    }
  }
}

class _OcrTab extends StatelessWidget {
  const _OcrTab({
    required this.busy,
    required this.status,
    required this.onCamera,
    required this.onGallery,
  });

  final bool busy;
  final String? status;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Take a photo of a printed receipt. We will extract items, total, cash, and change for you to review.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy ? null : onCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take photo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose from gallery'),
          ),
          const SizedBox(height: 24),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (status != null) ...[
            const SizedBox(height: 12),
            Text(status!, textAlign: TextAlign.center),
          ],
          const Spacer(),
          Text(
            'Tip: Place the receipt on a flat surface with good lighting for better accuracy.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _QrTab extends StatelessWidget {
  const _QrTab({required this.onDetect, required this.busy});

  final void Function(BarcodeCapture capture) onDetect;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(onDetect: onDetect),
        if (busy)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Point at a receipt or payment QR. BIR e-invoice codes usually need manual amount entry.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
