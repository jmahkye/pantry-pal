import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/models/pantry_item.dart';
import 'package:pantry_pal/services/gs1_parser.dart';
import 'package:pantry_pal/services/product_catalog.dart';

void main() {
  final scanDate = DateTime(2026, 7, 19);

  group('ProductCatalog.buildDraft expiry priority', () {
    test('GS1 use-by wins and is marked exact', () {
      final draft = ProductCatalog.buildDraft(
        gtin: '05000000000056',
        info: const ProductInfo(category: FoodCategory.dairy, shelfLifeDays: 7),
        gs1: Gs1Data(expiryDate: DateTime(2026, 8, 1)),
        scanDate: scanDate,
      );
      expect(draft.expiryDate, DateTime(2026, 8, 1));
      expect(draft.expiryIsExact, isTrue);
    });

    test('shelf life estimates from scan date and is marked estimated', () {
      final draft = ProductCatalog.buildDraft(
        gtin: '05000000000056',
        info: const ProductInfo(category: FoodCategory.dairy, shelfLifeDays: 7),
        gs1: const Gs1Data(),
        scanDate: scanDate,
      );
      expect(draft.expiryDate, DateTime(2026, 7, 26));
      expect(draft.expiryIsExact, isFalse);
    });

    test('long-life product (null shelf life) has no expiry', () {
      final draft = ProductCatalog.buildDraft(
        gtin: '5449000000996',
        info: const ProductInfo(category: FoodCategory.beverage),
        gs1: const Gs1Data(),
        scanDate: scanDate,
      );
      expect(draft.expiryDate, isNull);
      expect(draft.expiryIsExact, isTrue);
    });

    test('unknown product yields an empty name for manual/OCR entry', () {
      final draft = ProductCatalog.buildDraft(
        gtin: '0000000000000',
        info: null,
        gs1: const Gs1Data(),
        scanDate: scanDate,
      );
      expect(draft.name, '');
      expect(draft.category, FoodCategory.other);
      expect(draft.gtin, '0000000000000');
    });
  });
}
