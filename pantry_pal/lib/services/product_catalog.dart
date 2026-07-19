import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import '../models/pantry_item.dart';
import 'asset_db_installer.dart';
import 'gs1_parser.dart';

/// A product's reference data, from either the user table or the bundled dump.
class ProductInfo {
  final String? name;
  final String? brand;
  final FoodCategory category;
  final double? quantity;
  final String? unit;

  /// Days from purchase until it should be used. Null = long-life / ambient.
  final int? shelfLifeDays;

  const ProductInfo({
    this.name,
    this.brand,
    required this.category,
    this.quantity,
    this.unit,
    this.shelfLifeDays,
  });

  bool get isLongLife => shelfLifeDays == null;

  factory ProductInfo.fromRow(Map<String, Object?> row) {
    final (q, u) = _parseQuantity(row['quantity'] as String?);
    return ProductInfo(
      name: (row['name'] as String?)?.trim(),
      brand: (row['brand'] as String?)?.trim(),
      category: FoodCategory.fromName(row['category'] as String?),
      quantity: q,
      unit: u,
      shelfLifeDays: (row['shelf_life_days'] as num?)?.toInt(),
    );
  }

  /// The row shape shared by the bundled `products` and runtime `user_products`
  /// tables. Used when saving an OCR-confirmed product.
  Map<String, Object?> toRow(String gtin) => {
        'gtin': gtin,
        'name': name,
        'brand': brand,
        'quantity': quantity == null
            ? null
            : '${_trimNum(quantity!)}${unit ?? ''}',
        'category': category.name,
        'shelf_life_days': shelfLifeDays,
      };

  static (double?, String?) _parseQuantity(String? text) {
    if (text == null || text.trim().isEmpty) return (null, null);
    final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*([a-zA-Z]+)?').firstMatch(text);
    if (m == null) return (null, null);
    final q = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    final u = m.group(2);
    return (q, (u == null || u.isEmpty) ? null : u);
  }

  static String _trimNum(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

/// Offline product lookup. Checks the user's confirmed products first, then the
/// bundled read-only Open Food Facts dump. Makes no network calls.
class ProductCatalog {
  ProductCatalog({PantryDatabase? pantry})
      : _pantry = pantry ?? PantryDatabase.instance;

  final PantryDatabase _pantry;
  Database? _bundled;

  Future<Database> get _bundledDb async {
    if (_bundled != null) return _bundled!;
    final path = await AssetDbInstaller.instance.pathFor('products.db');
    return _bundled = await openDatabase(path, readOnly: true);
  }

  Future<ProductInfo?> lookup(String gtin) async {
    final userRow = await _pantry.findUserProduct(gtin);
    if (userRow != null) return ProductInfo.fromRow(userRow);

    final db = await _bundledDb;
    final rows = await db.query(
      'products',
      where: 'gtin = ?',
      whereArgs: [gtin],
      limit: 1,
    );
    if (rows.isNotEmpty) return ProductInfo.fromRow(rows.first);
    return null;
  }

  /// Persists an OCR-confirmed product to the user table for next time.
  Future<void> saveConfirmed(String gtin, ProductInfo info) async {
    await _pantry.upsertUserProduct(info.toRow(gtin));
  }

  /// Builds a pantry draft from a lookup hit and any GS1 data, applying the
  /// expiry priority: GS1 use-by (exact) → shelf-life estimate → long-life.
  static PantryItem buildDraft({
    required String gtin,
    ProductInfo? info,
    required Gs1Data gs1,
    required DateTime scanDate,
  }) {
    final DateTime? expiry;
    final bool exact;
    final gs1Expiry = gs1.effectiveExpiry;
    if (gs1Expiry != null) {
      expiry = gs1Expiry; // Authoritative.
      exact = true;
    } else if (info != null && info.shelfLifeDays != null) {
      expiry = DateTime(scanDate.year, scanDate.month, scanDate.day)
          .add(Duration(days: info.shelfLifeDays!)); // Estimated, editable.
      exact = false;
    } else {
      expiry = null; // Long-life or unknown.
      exact = true;
    }

    return PantryItem(
      name: info?.name ?? '',
      brand: info?.brand,
      gtin: gtin,
      category: info?.category ?? FoodCategory.other,
      quantity: info?.quantity,
      unit: info?.unit,
      expiryDate: expiry,
      expiryIsExact: exact,
      addedDate: scanDate,
    );
  }
}
