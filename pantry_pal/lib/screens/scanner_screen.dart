import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/database.dart';
import '../models/pantry_item.dart';
import '../services/gs1_parser.dart';
import '../services/open_food_facts.dart';
import '../services/product_image_cache.dart';

class ScanResult {
  final PantryItem? existing;
  final PantryItem? draft;
  const ScanResult({this.existing, this.draft});
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final OpenFoodFactsClient _api = OpenFoodFactsClient();
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

      final lookup = await _api.lookup(barcode);

      String? imagePath = lookup?.imageUrl;
      if (imagePath != null) {
        final local = await ProductImageCache.instance
            .download(barcode, imagePath);
        if (local != null) imagePath = local;
      }

      final draft = PantryItem(
        name: lookup?.name ?? 'Unknown product',
        brand: lookup?.brand,
        gtin: barcode,
        category: lookup?.category ?? FoodCategory.other,
        quantity: lookup?.quantity,
        unit: lookup?.unit,
        expiryDate: gs1.effectiveExpiry,
        // GS1 AI 17 is authoritative; a heuristic date would be marked estimated.
        expiryIsExact: gs1.effectiveExpiry != null,
        addedDate: DateTime.now(),
        imageUrl: imagePath,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ScanResult(draft: draft));
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
