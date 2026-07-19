import '../models/pantry_item.dart';
import '../models/recipe.dart';

abstract class RecipeGenerator {
  Future<List<Recipe>> suggest({
    required List<PantryItem> available,
    int maxResults = 5,
  });
}

/// Placeholder generator. Replaced later by an on-device model
/// (Apple FoundationModels on iOS, Gemini Nano / GGUF on Android).
class StubRecipeGenerator implements RecipeGenerator {
  const StubRecipeGenerator();

  @override
  Future<List<Recipe>> suggest({
    required List<PantryItem> available,
    int maxResults = 5,
  }) async {
    if (available.isEmpty) return const [];

    final byCategory = <FoodCategory, List<PantryItem>>{};
    for (final item in available) {
      byCategory.putIfAbsent(item.category, () => []).add(item);
    }

    final results = <Recipe>[];
    for (final template in _templates) {
      if (results.length >= maxResults) break;
      final matched = template.match(byCategory);
      if (matched != null) results.add(matched);
    }

    if (results.isEmpty) {
      results.add(_useItUpRecipe(available));
    }
    return results;
  }

  static Recipe _useItUpRecipe(List<PantryItem> available) {
    final soonest = [...available]..sort((a, b) {
        final ad = a.expiryDate;
        final bd = b.expiryDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    final picks = soonest.take(4).map((e) => e.name).toList();
    return Recipe(
      title: 'Use-it-up bowl',
      summary: 'Quick way to clear items nearing their expiry.',
      ingredients: picks,
      steps: const [
        'Prep ingredients into bite-sized pieces.',
        'Cook proteins first, then add starch and vegetables.',
        'Season to taste and serve.',
      ],
      prepTime: const Duration(minutes: 20),
    );
  }

  static const List<_Template> _templates = [
    _Template(
      title: 'Simple stir fry',
      summary: 'Throw together with whatever protein and veg you have.',
      required: [FoodCategory.produce],
      optional: [FoodCategory.meat, FoodCategory.grain, FoodCategory.condiment],
      steps: [
        'Heat oil in a wok or large pan over high heat.',
        'Sear the protein until just cooked, then set aside.',
        'Stir-fry the vegetables for 3–4 minutes.',
        'Return the protein, add sauce/condiments, and toss.',
      ],
      prepMinutes: 20,
    ),
    _Template(
      title: 'Pantry pasta',
      summary: 'Grain + whatever sauce-y ingredients you have.',
      required: [FoodCategory.grain],
      optional: [FoodCategory.dairy, FoodCategory.condiment, FoodCategory.produce],
      steps: [
        'Boil pasta in salted water.',
        'Meanwhile, gently warm any dairy/condiment with garlic.',
        'Drain pasta, reserving some water, then toss with sauce.',
        'Top with anything from the produce section.',
      ],
      prepMinutes: 15,
    ),
    _Template(
      title: 'Hearty omelette',
      summary: 'Eggs + leftover bits make a fast meal.',
      required: [FoodCategory.dairy],
      optional: [FoodCategory.produce, FoodCategory.meat],
      steps: [
        'Beat eggs with a splash of milk and seasoning.',
        'Sauté any fillings briefly in a non-stick pan.',
        'Pour eggs over the fillings; cook until just set.',
        'Fold and serve immediately.',
      ],
      prepMinutes: 10,
    ),
  ];
}

class _Template {
  final String title;
  final String summary;
  final List<FoodCategory> required;
  final List<FoodCategory> optional;
  final List<String> steps;
  final int prepMinutes;

  const _Template({
    required this.title,
    required this.summary,
    required this.required,
    required this.optional,
    required this.steps,
    required this.prepMinutes,
  });

  Recipe? match(Map<FoodCategory, List<PantryItem>> byCategory) {
    final picks = <PantryItem>[];
    for (final c in required) {
      final list = byCategory[c];
      if (list == null || list.isEmpty) return null;
      picks.add(list.first);
    }
    for (final c in optional) {
      final list = byCategory[c];
      if (list != null && list.isNotEmpty) picks.add(list.first);
    }
    return Recipe(
      title: title,
      summary: summary,
      ingredients: picks.map((e) => e.name).toList(),
      steps: steps,
      prepTime: Duration(minutes: prepMinutes),
    );
  }
}
