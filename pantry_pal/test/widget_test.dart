import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/services/gs1_parser.dart';

void main() {
  group('Gs1Parser', () {
    test('parses GTIN + expiry from Tesco-style DataMatrix', () {
      const raw = '01050000000000561726031510ABC123';
      final data = Gs1Parser.parse(raw);
      expect(data.gtin, '05000000000056');
      expect(data.expiryDate, DateTime(2026, 3, 15));
      expect(data.batch, 'ABC123');
    });

    test('handles symbology identifier prefix', () {
      const raw = ']d2010500000000005617251201';
      final data = Gs1Parser.parse(raw);
      expect(data.gtin, '05000000000056');
      expect(data.expiryDate, DateTime(2025, 12, 1));
    });

    test('returns empty for non-GS1 strings', () {
      final data = Gs1Parser.parse('99' * 20);
      expect(data.gtin, isNull);
      expect(data.expiryDate, isNull);
    });
  });
}
