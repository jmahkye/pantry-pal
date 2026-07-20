import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_pal/models/pantry_item.dart';
import 'package:pantry_pal/models/recipe.dart';
import 'package:pantry_pal/services/recipe_engine.dart';

PantryItem _item(String name) =>
    PantryItem(name: name, category: FoodCategory.other, addedDate: DateTime(2026));

void main() {
  group('RecipeEngine.dotProduct', () {
    test('computes the dot product', () {
      expect(RecipeEngine.dotProduct([1, 2, 3], [4, 5, 6]), 32);
    });

    test('normalised vectors give cosine similarity (1.0 when identical)', () {
      final v = [0.6, 0.8]; // unit length
      expect(RecipeEngine.dotProduct(v, v), closeTo(1.0, 1e-9));
    });

    test('throws on length mismatch', () {
      expect(() => RecipeEngine.dotProduct([1, 2], [1]), throwsArgumentError);
    });
  });

  group('RecipeEngine.decodeEmbedding', () {
    test('round-trips a float32 blob', () {
      final floats = Float32List.fromList([0.1, -0.2, 0.3]);
      final blob = floats.buffer.asUint8List();
      final decoded = RecipeEngine.decodeEmbedding(blob)!;
      expect(decoded.length, 3);
      expect(decoded[0], closeTo(0.1, 1e-6));
      expect(decoded[2], closeTo(0.3, 1e-6));
    });

    test('returns null for a non-blob or misaligned length', () {
      expect(RecipeEngine.decodeEmbedding(null), isNull);
      expect(RecipeEngine.decodeEmbedding(Uint8List(3)), isNull);
    });
  });

  group('RecipeEngine.ingredientOverlap', () {
    final recipe = Recipe(
      title: 'Cheese Toastie',
      summary: '',
      ingredients: const ['bread', 'cheddar', 'ham', 'butter'],
      steps: const [],
    );

    test('scores the fraction of ingredients the pantry covers', () {
      final score = RecipeEngine.ingredientOverlap(
        recipe,
        [_item('Sliced Bread'), _item('Mature Cheddar')],
      );
      expect(score, closeTo(0.5, 1e-9)); // bread + cheddar of 4
    });

    test('is zero when nothing matches', () {
      expect(RecipeEngine.ingredientOverlap(recipe, [_item('Bananas')]), 0);
    });
  });

  group('Recipe.fromRow', () {
    test('parses JSON ingredients/steps and numeric fields', () {
      final r = Recipe.fromRow({
        'title': 'Mac & Cheese',
        'summary': 'Cheesy',
        'meal_type': 'dinner',
        'diet_category': 'indulgent',
        'ingredients': jsonEncode(['macaroni', 'cheddar']),
        'steps': jsonEncode(['boil', 'bake']),
        'time_minutes': 30,
        'calories': 820,
      });
      expect(r.ingredients, ['macaroni', 'cheddar']);
      expect(r.steps.length, 2);
      expect(r.minutes, 30);
      expect(r.calories, 820);
      expect(r.mealType, 'dinner');
    });
  });
}
