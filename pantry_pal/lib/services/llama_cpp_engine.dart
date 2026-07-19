import 'dart:async';

import 'package:fllama/fllama.dart';

import 'ai_engine.dart';
import 'llm_model_manager.dart';

/// On-device language model backed by llama.cpp via the fllama plugin.
///
/// The context is loaded lazily on the first call and reused for subsequent
/// completions. Call [dispose] when you're done (e.g. on app shutdown).
class LlamaCppEngine implements AiEngine {
  LlamaCppEngine({
    this.model = kDefaultModel,
    this.contextSize = 2048,
    this.maxOutputTokens = 512,
    this.temperature = 0.7,
  });

  final LlmModelInfo model;
  final int contextSize;
  final int maxOutputTokens;
  final double temperature;

  double? _contextId;
  StreamSubscription<Map<Object?, dynamic>>? _tokenSub;

  @override
  String get name => model.displayName;

  @override
  Future<bool> isAvailable() async {
    if (Fllama.instance() == null) return false;
    return LlmModelManager.instance.isDownloaded(model);
  }

  Future<void> _ensureContext() async {
    if (_contextId != null) return;
    final fllama = Fllama.instance();
    if (fllama == null) {
      throw AiEngineException('fllama plugin not available on this platform.');
    }
    final file = await LlmModelManager.instance.fileFor(model);
    if (!await file.exists()) {
      throw AiEngineException(
          'Model file is missing. Download it from AI Settings first.');
    }
    final result = await fllama.initContext(
      file.path,
      nCtx: contextSize,
      nBatch: 512,
      nGpuLayers: 99, // Use GPU/Metal for all layers on iOS.
      useMlock: false,
      useMmap: true,
    );
    final id = result?['contextId'];
    if (id == null) {
      throw AiEngineException('initContext returned no contextId.');
    }
    _contextId = id is num ? id.toDouble() : double.parse(id.toString());
  }

  @override
  Future<String> complete(String prompt) async {
    await _ensureContext();
    final fllama = Fllama.instance()!;
    final ctxId = _contextId!;

    final buffer = StringBuffer();
    final done = Completer<void>();

    _tokenSub?.cancel();
    _tokenSub = fllama.onTokenStream?.listen((event) {
      if (event['function'] != 'completion') return;
      final result = event['result'];
      if (result is Map && result['token'] is String) {
        buffer.write(result['token'] as String);
      }
    });

    try {
      await fllama.completion(
        ctxId,
        prompt: _format(prompt),
        nPredict: maxOutputTokens,
        temperature: temperature,
        stop: _stopTokens(),
        emitRealtimeCompletion: true,
      );
      if (!done.isCompleted) done.complete();
    } catch (e) {
      throw AiEngineException('completion failed: $e');
    } finally {
      await _tokenSub?.cancel();
      _tokenSub = null;
    }

    return buffer.toString();
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
    final id = _contextId;
    _contextId = null;
    if (id != null) {
      try {
        await Fllama.instance()?.releaseContext(id);
      } catch (_) {}
    }
  }

  static const _systemPrompt =
      'You follow instructions exactly and respond with JSON when asked.';

  String _format(String userPrompt) {
    switch (model.template) {
      case ChatTemplate.llama3:
        return '<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n'
            '$_systemPrompt'
            '<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n'
            '$userPrompt'
            '<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n';
      case ChatTemplate.chatml:
        return '<|im_start|>system\n$_systemPrompt<|im_end|>\n'
            '<|im_start|>user\n$userPrompt<|im_end|>\n'
            '<|im_start|>assistant\n';
    }
  }

  List<String> _stopTokens() {
    switch (model.template) {
      case ChatTemplate.llama3:
        return const ['<|eot_id|>', '<|end_of_text|>'];
      case ChatTemplate.chatml:
        return const ['<|im_end|>', '<|endoftext|>'];
    }
  }
}
