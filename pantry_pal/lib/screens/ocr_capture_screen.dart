import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pantry_item.dart';
import '../services/ocr_service.dart';

/// Barcode-miss fallback: with a live in-app camera preview, capture the
/// product name and then the use-by date using on-device OCR. Returns a draft
/// [PantryItem] to confirm on the edit screen — OCR guesses are never stored
/// silently.
class OcrCaptureScreen extends StatefulWidget {
  const OcrCaptureScreen({super.key, required this.seed});

  /// Carries the scanned GTIN and any GS1 date already found.
  final PantryItem seed;

  @override
  State<OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

class _OcrCaptureScreenState extends State<OcrCaptureScreen>
    with WidgetsBindingObserver {
  final OcrService _ocr = OcrService();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.seed.name);
  CameraController? _controller;
  DateTime? _date;
  bool _busy = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _date = widget.seed.expiryDate;
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _nameCtrl.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    // Release the camera when backgrounded; re-acquire when resumed.
    if (state == AppLifecycleState.inactive) {
      c.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _setError('No camera available on this device.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cameraError = null;
      });
    } catch (e) {
      _setError('Camera unavailable — you can still type the details in.');
    }
  }

  void _setError(String msg) {
    if (mounted) setState(() => _cameraError = msg);
  }

  Future<void> _captureName() => _capture(forDate: false);
  Future<void> _captureDate() => _capture(forDate: true);

  Future<void> _capture({required bool forDate}) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await c.takePicture();
      if (forDate) {
        final date = await _ocr.recogniseDate(shot.path);
        if (date != null) {
          _date = date;
        } else {
          _snack('No date found — try again or set it by hand.');
        }
      } else {
        final name = await _ocr.recogniseName(shot.path);
        if (name != null) {
          _nameCtrl.text = name;
        } else {
          _snack('No product name found — try again or type it in.');
        }
      }
    } catch (e) {
      _snack('Capture failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDateManually() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _continue() {
    // An OCR-read printed date is the actual use-by, so it counts as exact;
    // the user still confirms/edits it on the next screen.
    final draft = widget.seed.copyWith(
      name: _nameCtrl.text.trim(),
      expiryDate: _date,
      expiryIsExact: _date != null,
      clearExpiry: _date == null,
    );
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _nameCtrl.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Capture details')),
      body: Stack(
        children: [
          Column(
            children: [
              _preview(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      "We didn't recognise that barcode. Frame the label in the "
                      'preview above and capture the details — read on-device.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    const _StepHeader(number: 1, label: 'Product name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Aim at the largest text on the pack',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed:
                          (_controller == null || _busy) ? null : _captureName,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture name'),
                    ),
                    const SizedBox(height: 24),
                    const _StepHeader(number: 2, label: 'Use-by date'),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Use-by',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _date == null
                            ? 'Not set'
                            : DateFormat.yMMMd().format(_date!),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: (_controller == null || _busy)
                              ? null
                              : _captureDate,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture date'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _busy ? null : _pickDateManually,
                          child: const Text('Set by hand'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: canContinue ? _continue : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _preview() {
    final c = _controller;
    return Container(
      height: 260,
      width: double.infinity,
      color: Colors.black,
      child: c != null && c.value.isInitialized
          ? CameraPreview(c)
          : Center(
              child: _cameraError != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _cameraError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text('$number',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
