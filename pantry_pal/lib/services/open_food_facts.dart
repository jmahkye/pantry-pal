import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/pantry_item.dart';

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

class ProductLookupResult {
  final String? name;
  final String? brand;
  final FoodCategory category;
  final double? quantity;
  final String? unit;
  final String? imageUrl;

  const ProductLookupResult({
    this.name,
    this.brand,
    required this.category,
    this.quantity,
    this.unit,
    this.imageUrl,
  });
}

class OpenFoodFactsClient {
  OpenFoodFactsClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ProductLookupResult?> lookup(String barcode) async {
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,generic_name,brands,categories_tags,quantity,product_quantity,product_quantity_unit,image_front_url,image_front_small_url,image_url');
    try {
      final resp = await _client
          .get(uri, headers: {'User-Agent': 'PantryPal/0.1 (flutter)'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final body = json.decode(resp.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null;
      final product = body['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final productName = (product['product_name'] as String?)?.trim();
      final genericName = (product['generic_name'] as String?)?.trim();
      final name = (productName != null && productName.isNotEmpty)
          ? productName
          : (genericName != null && genericName.isNotEmpty ? genericName : null);
      final brand = (product['brands'] as String?)?.trim().split(',').first.trim();
      final categories = (product['categories_tags'] as List?)?.cast<String>() ?? const [];
      final (q, u) = _parseQuantity(
        product['product_quantity'],
        product['product_quantity_unit'] as String?,
        product['quantity'] as String?,
      );
      final imageUrl = (product['image_front_small_url'] as String?)?.trim().nullIfEmpty ??
          (product['image_front_url'] as String?)?.trim().nullIfEmpty ??
          (product['image_url'] as String?)?.trim().nullIfEmpty;

      return ProductLookupResult(
        name: name,
        brand: brand?.isEmpty ?? true ? null : brand,
        category: _mapCategory(categories),
        quantity: q,
        unit: u,
        imageUrl: imageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static (double?, String?) _parseQuantity(
    Object? productQuantity,
    String? productQuantityUnit,
    String? quantityText,
  ) {
    double? q;
    if (productQuantity is num) {
      q = productQuantity.toDouble();
    } else if (productQuantity is String) {
      q = double.tryParse(productQuantity);
    }
    String? u = productQuantityUnit?.trim();
    if (q != null) return (q, (u == null || u.isEmpty) ? null : u);

    // Fall back to parsing the free-text "quantity" like "500 g" or "1L".
    if (quantityText == null) return (null, null);
    final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*([a-zA-Z]+)').firstMatch(quantityText);
    if (m == null) return (null, null);
    return (double.tryParse(m.group(1)!.replaceAll(',', '.')), m.group(2));
  }

  static FoodCategory _mapCategory(List<String> tags) {
    bool has(String needle) => tags.any((t) => t.contains(needle));
    if (has('dairy') || has('milk') || has('cheese') || has('yogurt')) {
      return FoodCategory.dairy;
    }
    if (has('meat') || has('poultry') || has('sausage')) return FoodCategory.meat;
    if (has('seafood') || has('fish')) return FoodCategory.seafood;
    if (has('frozen-foods')) return FoodCategory.frozen;
    if (has('beverages') || has('drinks')) return FoodCategory.beverage;
    if (has('snack')) return FoodCategory.snack;
    if (has('bread') || has('bakery')) return FoodCategory.bakery;
    if (has('cereals') || has('pasta') || has('rice')) return FoodCategory.grain;
    if (has('fruit') || has('vegetable')) return FoodCategory.produce;
    if (has('sauce') || has('condiment') || has('dressing')) {
      return FoodCategory.condiment;
    }
    if (has('canned') || has('staple') || has('legume') || has('groceries')) {
      return FoodCategory.pantryStaple;
    }
    return FoodCategory.other;
  }
}
