import 'ai_engine.dart';

/// Deterministic, offline engine that returns a canned JSON response.
/// Useful for development and as a smoke-test fallback while a real local
/// model isn't wired up yet.
class StubAiEngine implements AiEngine {
  const StubAiEngine();

  @override
  String get name => 'Stub';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> complete(String prompt) async {
    return '''
{
  "recipes": [
    {
      "title": "Pantry toss",
      "summary": "A quick made-up recipe to verify the AI plumbing works end-to-end.",
      "ingredients": ["whatever's in the pantry"],
      "steps": [
        "Replace StubAiEngine with a real model implementation.",
        "Cook and enjoy."
      ],
      "prepMinutes": 15
    }
  ]
}
''';
  }
}
