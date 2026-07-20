import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device OCR for the barcode-miss fallback. Runs Google ML Kit's text
/// recogniser entirely on the device — no network. Also hosts the pure parsing
/// helpers (name cleanup, UK date parsing) so they can be unit-tested.
class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<void> dispose() => _recognizer.close();

  /// Best-guess product name from a photo: the largest text lines, with
  /// weights/prices/multipack noise stripped out.
  Future<String?> recogniseName(String imagePath) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    // Sort blocks by height (largest text first) and flatten to lines.
    final blocks = [...result.blocks]
      ..sort((a, b) => b.boundingBox.height.compareTo(a.boundingBox.height));
    final lines = <String>[
      for (final b in blocks)
        for (final l in b.lines) l.text,
    ];
    return cleanProductName(lines);
  }

  /// Best-guess use-by date from a photo of the printed date.
  Future<DateTime?> recogniseDate(String imagePath) async {
    final result = await _recognizer.processImage(
      InputImage.fromFilePath(imagePath),
    );
    return parseUseByDate(result.text);
  }

  // --- Pure helpers (unit-tested) ---

  static final _noise = [
    RegExp(r'£\s*\d+(\.\d+)?'), // prices
    RegExp(r'\b\d+(\.\d+)?\s*(kg|g|ml|cl|l)\b', caseSensitive: false), // weights
    RegExp(r'\b\d+\s*%'), // percentages
    RegExp(r'\bx\s*\d+\b', caseSensitive: false), // multipacks
  ];

  /// Picks the first "product-name-like" line: drops prices, weights, pure
  /// numbers and very short fragments. Input should be largest-text-first.
  static String? cleanProductName(List<String> lines) {
    for (final raw in lines) {
      var line = raw.trim();
      for (final re in _noise) {
        line = line.replaceAll(re, '');
      }
      line = line.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      if (line.length < 3) continue;
      if (RegExp(r'^[\d\W]+$').hasMatch(line)) continue; // no letters
      return line;
    }
    return null;
  }

  static const _months = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  /// Parses UK-style printed dates: "USE BY 15 OCT", "15/10/26",
  /// "15.10.2026", or a bare "15 OCT" (→ the nearest future occurrence).
  static DateTime? parseUseByDate(String raw, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final text = raw.toUpperCase();

    // Numeric: dd/mm/yy(yy) or dd.mm.yy(yy)
    final numMatch =
        RegExp(r'\b(\d{1,2})[\/.](\d{1,2})[\/.](\d{2,4})\b').firstMatch(text);
    if (numMatch != null) {
      final d = int.parse(numMatch.group(1)!);
      final mo = int.parse(numMatch.group(2)!);
      final dt = _valid(_fullYear(int.parse(numMatch.group(3)!)), mo, d);
      if (dt != null) return dt;
    }

    // Named month: "15 OCT", "15 OCT 2026", "15OCT26"
    for (final m
        in RegExp(r'\b(\d{1,2})\s*([A-Z]{3,9})\.?\s*(\d{2,4})?').allMatches(text)) {
      final d = int.parse(m.group(1)!);
      final mo = _months[m.group(2)!.substring(0, 3)];
      if (mo == null) continue;
      final yg = m.group(3);
      if (yg != null) {
        final dt = _valid(_fullYear(int.parse(yg)), mo, d);
        if (dt != null) return dt;
      } else {
        // No year printed → nearest future occurrence.
        final thisYear = _valid(today.year, mo, d);
        if (thisYear == null) continue;
        return thisYear.isBefore(DateTime(today.year, today.month, today.day))
            ? _valid(today.year + 1, mo, d)
            : thisYear;
      }
    }
    return null;
  }

  static int _fullYear(int y) => y < 100 ? 2000 + y : y;

  /// Builds a DateTime only if the components round-trip (rejects e.g. 31 Feb).
  static DateTime? _valid(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    return (dt.year == y && dt.month == m && dt.day == d) ? dt : null;
  }
}
