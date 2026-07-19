import 'dart:convert';

import '../models/pantry_item.dart';
import '../models/recipe.dart';
import 'ai_engine.dart';
import 'recipe_generator.dart';

/// Recipe generator that turns the pantry into a text prompt, hands it to
/// an [AiEngine], and parses the JSON response into [Recipe]s.
///
/// The engine is fully swappable — change AI backends without touching the
/// prompt template or response schema.
class AiRecipeGenerator implements RecipeGenerator {
  AiRecipeGenerator({
    required this.engine,
    RecipeGenerator? fallback,
  }) : _fallback = fallback ?? const StubRecipeGenerator();

  final AiEngine engine;
  final RecipeGenerator _fallback;

  @override
  Future<List<Recipe>> suggest({
    required List<PantryItem> available,
    int maxResults = 5,
  }) async {
    if (available.isEmpty) return const [];
    if (!await engine.isAvailable()) {
      return _fallback.suggest(available: available, maxResults: maxResults);
    }
    try {
      final prompt = buildPrompt(available, maxResults: maxResults);
      final raw = await engine.complete(prompt);
      final recipes = _parseRecipes(raw);
      if (recipes.isEmpty) {
        return _fallback.suggest(
            available: available, maxResults: maxResults);
      }
      return recipes.take(maxResults).toList();
    } catch (_) {
      return _fallback.suggest(available: available, maxResults: maxResults);
    }
  }

  /// Exposed so callers and tests can inspect the prompt sent to the engine.
  static String buildPrompt(
    List<PantryItem> items, {
    int maxResults = 5,
  }) {
    final lines = items.map(_lineFor).join('\n');
    return '''
You are a recipe assistant. Suggest up to $maxResults simple recipes a home cook can make using ONLY the pantry items below. Assume basic staples (salt, pepper, oil, water) are always available. Prefer items whose expiry date is soonest.

Pantry:
$lines

Respond with JSON only — no prose, no markdown fences — matching this schema exactly:
{
  "recipes": [
    {
      "title": "string",
      "summary": "one short sentence",
      "ingredients": ["string", "..."],
      "steps": ["string", "..."],
      "prepMinutes": 20
    }
  ]
}
''';
  }

  static String _lineFor(PantryItem item) {
    final parts = <String>[item.name];
    if (item.brand != null) parts.add('(${item.brand})');
    if (item.quantity != null) {
      final unit = item.unit ?? '';
      parts.add('${_fmtQty(item.quantity!)}$unit');
    }
    if (item.expiryDate != null) {
      parts.add('exp ${item.expiryDate!.toIso8601String().substring(0, 10)}');
    }
    return '- ${parts.join(' ')}';
  }

  static String _fmtQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

  static List<Recipe> _parseRecipes(String raw) {
    final cleaned = _stripFences(raw).trim();
    if (cleaned.isEmpty) return const [];
    final decoded = json.decode(cleaned);
    if (decoded is! Map<String, dynamic>) return const [];
    final list = (decoded['recipes'] as List?) ?? const [];
    return list.whereType<Map<String, dynamic>>().map((map) {
      final minutes = (map['prepMinutes'] as num?)?.toInt();
      return Recipe(
        title: (map['title'] as String?)?.trim().isNotEmpty == true
            ? map['title'] as String
            : 'Recipe',
        summary: (map['summary'] as String?) ?? '',
        ingredients: ((map['ingredients'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        steps:
            ((map['steps'] as List?) ?? const []).whereType<String>().toList(),
        prepTime: minutes != null ? Duration(minutes: minutes) : null,
      );
    }).toList();
  }

  /// Some models like to wrap JSON in ```json fences despite instructions.
  static String _stripFences(String s) {
    final fence = RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true);
    return s.replaceAll(fence, '');
  }
}
