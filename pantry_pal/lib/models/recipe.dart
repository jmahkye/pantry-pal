class Recipe {
  final String title;
  final String summary;
  final List<String> ingredients;
  final List<String> steps;
  final Duration? prepTime;

  const Recipe({
    required this.title,
    required this.summary,
    required this.ingredients,
    required this.steps,
    this.prepTime,
  });
}
