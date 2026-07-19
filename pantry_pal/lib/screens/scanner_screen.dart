import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/database.dart';
import '../models/pantry_item.dart';
import '../services/gs1_parser.dart';
import '../services/product_catalog.dart';

class ScanResult {
  /// Set when the scanned item is already in the pantry.
  final PantryItem? existing;

  /// A draft to confirm/add. [productFound] is false when neither the user
  /// table nor the bundled dump knew the GTIN — the caller runs OCR fallback.
  final PantryItem? draft;
  final bool productFound;

  const ScanResult({this.existing, this.draft, this.productFound = false});
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final ProductCatalog _catalog = ProductCatalog();
  bool _processing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final gs1 = Gs1Parser.parse(raw);
      final barcode = gs1.gtin ?? raw;

      final existing = await PantryDatabase.instance.findByGtin(barcode);
      if (existing != null && mounted) {
        Navigator.of(context).pop(ScanResult(existing: existing));
        return;
      }

      // Offline lookup: user table first, then the bundled products.db.
      final info = await _catalog.lookup(barcode);
      final draft = ProductCatalog.buildDraft(
        gtin: barcode,
        info: info,
        gs1: gs1,
        scanDate: DateTime.now(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        ScanResult(draft: draft, productFound: info != null),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
      setState(() => _processing = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Looking up product…',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Point the camera at a barcode or QR code',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
