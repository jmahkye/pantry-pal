/// A text-in, text-out language model.
///
/// Implementations should be cheap to construct and stateless across calls.
/// The recipe layer is responsible for prompt construction and response
/// parsing — engines only know how to turn a prompt into a completion.
abstract class AiEngine {
  /// Short identifier shown in the UI (e.g. "Stub", "Apple Intelligence").
  String get name;

  /// Whether the engine can currently service requests (model present,
  /// platform supported, network reachable, etc.).
  Future<bool> isAvailable();

  /// Returns the model's completion for [prompt].
  ///
  /// Throws [AiEngineException] on failure. Callers should treat this as
  /// recoverable and fall back to another generator if appropriate.
  Future<String> complete(String prompt);
}

class AiEngineException implements Exception {
  AiEngineException(this.message);
  final String message;
  @override
  String toString() => 'AiEngineException: $message';
}
