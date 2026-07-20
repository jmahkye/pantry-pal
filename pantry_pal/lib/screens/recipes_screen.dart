import 'package:flutter/material.dart';

import '../data/database.dart';
import '../models/recipe.dart';
import '../services/recipe_engine.dart';

/// Suggests recipes from the bundled recipes.db for the chosen meal type and
/// diet, ranked against the in-date pantry. Fully offline.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, this.engine});

  /// Injectable for tests; defaults to an offline [RecipeEngine].
  final RecipeEngine? engine;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late final RecipeEngine _engine = widget.engine ?? RecipeEngine();
  String _mealType = 'dinner';
  String _dietCategory = 'normal';
  late Future<List<Recipe>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _load();
  }

  Future<List<Recipe>> _load() async {
    final all = await PantryDatabase.instance.all();
    // Only cook with what hasn't expired.
    final inDate = all
        .where((i) => i.daysUntilExpiry == null || i.daysUntilExpiry! >= 0)
        .toList();
    return _engine.suggest(
      available: inDate,
      mealType: _mealType,
      dietCategory: _dietCategory,
    );
  }

  void _reload() => setState(() => _recipesFuture = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _Selectors(
            mealType: _mealType,
            dietCategory: _dietCategory,
            onMeal: (v) {
              setState(() => _mealType = v);
              _reload();
            },
            onDiet: (v) {
              setState(() => _dietCategory = v);
              _reload();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Recipe>>(
              future: _recipesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _LoadingState();
                }
                final recipes = snapshot.data ?? const [];
                if (recipes.isEmpty) return const _EmptyRecipes();
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: recipes.length + 1,
                    itemBuilder: (context, i) {
                      if (i == recipes.length) return const _SourceFooter();
                      return _RecipeCard(recipe: recipes[i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Selectors extends StatelessWidget {
  const _Selectors({
    required this.mealType,
    required this.dietCategory,
    required this.onMeal,
    required this.onDiet,
  });

  final String mealType;
  final String dietCategory;
  final ValueChanged<String> onMeal;
  final ValueChanged<String> onDiet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'lunch', label: Text('Lunch')),
              ButtonSegment(value: 'dinner', label: Text('Dinner')),
            ],
            selected: {mealType},
            onSelectionChanged: (s) => onMeal(s.first),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'healthy', label: Text('Healthy')),
              ButtonSegment(value: 'normal', label: Text('Normal')),
              ButtonSegment(value: 'indulgent', label: Text('Indulgent')),
            ],
            selected: {dietCategory},
            onSelectionChanged: (s) => onDiet(s.first),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyRecipes extends StatelessWidget {
  const _EmptyRecipes();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No recipes for that choice yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different meal or diet, or add more items to your pantry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceFooter extends StatelessWidget {
  const _SourceFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Matched on-device from your pantry. No network calls.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recipe.title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (recipe.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(recipe.summary,
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (recipe.minutes != null)
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text('${recipe.minutes} min'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (recipe.calories != null)
                  Chip(
                    avatar: const Icon(Icons.local_fire_department, size: 16),
                    label: Text('${recipe.calories} kcal'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Ingredients',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recipe.ingredients
                  .map((i) => Chip(
                        label: Text(i),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('Steps', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (var i = 0; i < recipe.steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${i + 1}. ${recipe.steps[i]}'),
              ),
          ],
        ),
      ),
    );
  }
}
