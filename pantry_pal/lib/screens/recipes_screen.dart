import 'package:flutter/material.dart';

import '../data/database.dart';
import '../models/recipe.dart';
import '../services/recipe_generator.dart';

/// Suggests things to cook from what's in the pantry. Fully offline — the
/// generator runs on-device with no network calls. Step 5 swaps the template
/// generator for the fonnx/MiniLM retrieval engine.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, this.generator = const StubRecipeGenerator()});

  final RecipeGenerator generator;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  late Future<List<Recipe>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _load();
  }

  Future<List<Recipe>> _load() async {
    final items = await PantryDatabase.instance.all();
    return widget.generator.suggest(available: items);
  }

  Future<void> _refresh() async {
    setState(() => _recipesFuture = _load());
    await _recipesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LoadingState();
          }
          final recipes = snapshot.data ?? const [];
          if (recipes.isEmpty) {
            return const _EmptyRecipes();
          }
          return RefreshIndicator(
            onRefresh: _refresh,
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
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Thinking up recipes…', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
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
              'Nothing to suggest yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Add a few items to your pantry and we’ll suggest things to cook.',
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
              'Suggested on-device. No network calls.',
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipe.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                if (recipe.prepTime != null)
                  Chip(
                    label: Text('${recipe.prepTime!.inMinutes} min'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(recipe.summary,
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            const Text('Uses', style: TextStyle(fontWeight: FontWeight.w600)),
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
