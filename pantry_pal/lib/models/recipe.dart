import 'dart:convert';

class Recipe {
  final String title;
  final String summary;
  final List<String> ingredients;
  final List<String> steps;
  final Duration? prepTime;
  final String? mealType; // lunch | dinner
  final String? dietCategory; // healthy | normal | indulgent
  final int? timeMinutes;
  final int? calories;

  const Recipe({
    required this.title,
    required this.summary,
    required this.ingredients,
    required this.steps,
    this.prepTime,
    this.mealType,
    this.dietCategory,
    this.timeMinutes,
    this.calories,
  });

  /// Minutes to show on a card: explicit time, else derived from [prepTime].
  int? get minutes => timeMinutes ?? prepTime?.inMinutes;

  /// Builds a Recipe from a bundled `recipes` row. `ingredients`/`steps` are
  /// stored as JSON arrays; `summary` is optional so it falls back to a blank.
  factory Recipe.fromRow(Map<String, Object?> row) {
    List<String> jsonList(Object? v) {
      if (v is! String || v.isEmpty) return const [];
      final decoded = jsonDecode(v);
      return decoded is List ? decoded.map((e) => '$e').toList() : const [];
    }

    final time = (row['time_minutes'] as num?)?.toInt();
    return Recipe(
      title: (row['title'] as String?) ?? 'Untitled',
      summary: (row['summary'] as String?) ?? '',
      ingredients: jsonList(row['ingredients']),
      steps: jsonList(row['steps']),
      prepTime: time == null ? null : Duration(minutes: time),
      mealType: row['meal_type'] as String?,
      dietCategory: row['diet_category'] as String?,
      timeMinutes: time,
      calories: (row['calories'] as num?)?.toInt(),
    );
  }
}
