import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../models/pantry_item.dart';
import '../models/recipe.dart';
import 'asset_db_installer.dart';

/// Produces a query embedding for semantic ranking. The real implementation
/// runs `assets/miniLmL6V2.onnx` via the `fonnx` package; until that model is
/// bundled, [NoQueryEmbedder] returns null and the engine falls back to
/// ingredient-overlap ranking. Wire a fonnx-backed embedder here when ready.
abstract class RecipeQueryEmbedder {
  Future<Float32List?> embed(String text);
}

class NoQueryEmbedder implements RecipeQueryEmbedder {
  const NoQueryEmbedder();
  @override
  Future<Float32List?> embed(String text) async => null;
}

/// Retrieval over the bundled `recipes.db`: filter by meal type + diet category
/// in SQL, then rank. If the model and stored embeddings are present, ranking
/// is dot-product (cosine) similarity of pre-normalised MiniLM vectors;
/// otherwise it falls back to how many ingredients the pantry already covers.
/// Fully offline.
class RecipeEngine {
  RecipeEngine({RecipeQueryEmbedder embedder = const NoQueryEmbedder()})
      : _embedder = embedder;

  final RecipeQueryEmbedder _embedder;
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = await AssetDbInstaller.instance.pathFor('recipes.db');
    return _db = await openDatabase(path, readOnly: true);
  }

  Future<List<Recipe>> suggest({
    required List<PantryItem> available,
    required String mealType,
    required String dietCategory,
    int maxResults = 5,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'recipes',
      where: 'meal_type = ? AND diet_category = ?',
      whereArgs: [mealType, dietCategory],
    );
    if (rows.isEmpty) return const [];

    // Preferred path: semantic ranking against pre-computed embeddings.
    final queryVec = await _embedder.embed(_pantryQuery(available));
    if (queryVec != null) {
      final scored = <_Scored>[];
      for (final row in rows) {
        final emb = decodeEmbedding(row['embedding']);
        if (emb != null && emb.length == queryVec.length) {
          scored.add(_Scored(Recipe.fromRow(row), dotProduct(queryVec, emb)));
        }
      }
      if (scored.isNotEmpty) return _top(scored, maxResults);
    }

    // Fallback: rank by how much of each recipe the pantry already covers.
    final scored = [
      for (final row in rows)
        _Scored(Recipe.fromRow(row),
            ingredientOverlap(Recipe.fromRow(row), available)),
    ];
    return _top(scored, maxResults);
  }

  static List<Recipe> _top(List<_Scored> scored, int maxResults) {
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((s) => s.recipe).toList();
  }

  static String _pantryQuery(List<PantryItem> items) =>
      items.map((e) => e.name).join(', ');

  /// Fraction of a recipe's ingredients that loosely match a pantry item name.
  static double ingredientOverlap(Recipe recipe, List<PantryItem> pantry) {
    if (recipe.ingredients.isEmpty) return 0;
    final names = pantry.map((e) => e.name.toLowerCase()).toList();
    var hits = 0;
    for (final ing in recipe.ingredients) {
      final i = ing.toLowerCase();
      if (names.any((n) => n.contains(i) || i.contains(n))) hits++;
    }
    return hits / recipe.ingredients.length;
  }

  /// Decodes a stored 384-d float32 embedding BLOB. Returns null if absent or
  /// not a whole number of floats.
  static Float32List? decodeEmbedding(Object? blob) {
    if (blob is! Uint8List || blob.lengthInBytes % 4 != 0) return null;
    // Copy to guarantee 4-byte alignment before viewing as floats.
    final copy = Uint8List.fromList(blob);
    return copy.buffer.asFloat32List();
  }

  /// Dot product of equal-length vectors. Embeddings are L2-normalised, so this
  /// equals cosine similarity.
  static double dotProduct(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vector length mismatch: ${a.length} vs ${b.length}');
    }
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }
}

class _Scored {
  const _Scored(this.recipe, this.score);
  final Recipe recipe;
  final double score;
}
