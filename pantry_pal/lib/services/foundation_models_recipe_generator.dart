import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/pantry_item.dart';
import '../models/recipe.dart';
import 'recipe_generator.dart';

/// Recipe generator backed by Apple's on-device Foundation Models.
/// Falls back to [fallback] if the platform/runtime can't satisfy the call.
class FoundationModelsRecipeGenerator implements RecipeGenerator {
  FoundationModelsRecipeGenerator({RecipeGenerator? fallback})
      : _fallback = fallback ?? const StubRecipeGenerator();

  static const _channel = MethodChannel('com.jmak.pantry_pal/recipes');
  final RecipeGenerator _fallback;
  bool? _cachedAvailability;

  Future<bool> isAvailable() async {
    if (kIsWeb || !Platform.isIOS) return false;
    if (_cachedAvailability != null) return _cachedAvailability!;
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      _cachedAvailability = result ?? false;
    } on PlatformException {
      _cachedAvailability = false;
    } on MissingPluginException {
      _cachedAvailability = false;
    }
    return _cachedAvailability!;
  }

  @override
  Future<List<Recipe>> suggest({
    required List<PantryItem> available,
    int maxResults = 5,
  }) async {
    if (!await isAvailable()) {
      return _fallback.suggest(available: available, maxResults: maxResults);
    }
    try {
      final pantry = available.map(_toMap).toList();
      final raw = await _channel.invokeMethod<String>('generate', {
        'pantry': pantry,
        'maxResults': maxResults,
      });
      if (raw == null) {
        return _fallback.suggest(available: available, maxResults: maxResults);
      }
      return _parseRecipes(raw);
    } catch (_) {
      return _fallback.suggest(available: available, maxResults: maxResults);
    }
  }

  static Map<String, Object?> _toMap(PantryItem item) => {
        'name': item.name,
        'brand': item.brand,
        'category': item.category.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'expiryDate': item.expiryDate?.toIso8601String().substring(0, 10),
      };

  static List<Recipe> _parseRecipes(String raw) {
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = (decoded['recipes'] as List?) ?? const [];
    return list.map((r) {
      final map = r as Map<String, dynamic>;
      final minutes = (map['prepMinutes'] as num?)?.toInt();
      return Recipe(
        title: map['title'] as String? ?? 'Recipe',
        summary: map['summary'] as String? ?? '',
        ingredients: ((map['ingredients'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        steps:
            ((map['steps'] as List?) ?? const []).whereType<String>().toList(),
        prepTime: minutes != null ? Duration(minutes: minutes) : null,
      );
    }).toList();
  }
}
