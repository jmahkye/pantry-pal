import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/services/ocr_service.dart';

void main() {
  final now = DateTime(2026, 7, 19);

  group('OcrService.parseUseByDate', () {
    test('"USE BY 15 OCT" picks the nearest future 15 Oct', () {
      expect(OcrService.parseUseByDate('USE BY 15 OCT', now: now),
          DateTime(2026, 10, 15));
    });

    test('bare past month in the year rolls to next year', () {
      // 15 Jan is already past on 19 Jul 2026 -> 2027.
      expect(OcrService.parseUseByDate('15 JAN', now: now),
          DateTime(2027, 1, 15));
    });

    test('numeric dd/mm/yy', () {
      expect(OcrService.parseUseByDate('15/10/26', now: now),
          DateTime(2026, 10, 15));
    });

    test('numeric dd.mm.yyyy', () {
      expect(OcrService.parseUseByDate('Best before 15.10.2026', now: now),
          DateTime(2026, 10, 15));
    });

    test('named month with year', () {
      expect(OcrService.parseUseByDate('USE BY 15 OCT 2026', now: now),
          DateTime(2026, 10, 15));
    });

    test('rejects impossible dates', () {
      expect(OcrService.parseUseByDate('31/02/26', now: now), isNull);
    });

    test('returns null when there is no date', () {
      expect(OcrService.parseUseByDate('Organic Oat Milk', now: now), isNull);
    });
  });

  group('OcrService.cleanProductName', () {
    test('picks the first name-like line, stripping weights/prices', () {
      final name = OcrService.cleanProductName([
        '£1.99',
        '500g',
        'Cathedral City Mature Cheddar',
        'x4',
      ]);
      expect(name, 'Cathedral City Mature Cheddar');
    });

    test('strips inline weight from an otherwise good line', () {
      final name = OcrService.cleanProductName(['Semi Skimmed Milk 2L']);
      expect(name, 'Semi Skimmed Milk');
    });

    test('returns null when nothing looks like a name', () {
      expect(OcrService.cleanProductName(['£2.50', '750ml', '20%']), isNull);
    });
  });
}
