import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ChatTemplate { llama3, chatml }

class LlmModelInfo {
  const LlmModelInfo({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.downloadUrl,
    required this.approxBytes,
    required this.template,
  });

  final String id;
  final String displayName;
  final String fileName;
  final String downloadUrl;
  final int approxBytes;
  final ChatTemplate template;
}

/// Hard-coded catalogue of supported on-device models.
///
/// Default is SmolLM2 360M Instruct (Q4_K_M, ~270 MB) — the smallest model
/// that still does instruction-following. Quality is modest; expect the
/// fallback generator to kick in occasionally. To upgrade to a larger model,
/// edit this constant.
const LlmModelInfo kDefaultModel = LlmModelInfo(
  id: 'smollm2-360m-instruct-q4km',
  displayName: 'SmolLM2 360M Instruct (Q4_K_M)',
  fileName: 'smollm2-360m-instruct-q4_k_m.gguf',
  downloadUrl:
      'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q4_k_m.gguf?download=true',
  approxBytes: 270 * 1024 * 1024,
  template: ChatTemplate.chatml,
);

/// Status snapshot for the UI.
class LlmDownloadProgress {
  const LlmDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });
  final int receivedBytes;
  final int totalBytes;

  double get fraction =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class LlmModelManager {
  LlmModelManager._();
  static final LlmModelManager instance = LlmModelManager._();

  final http.Client _client = http.Client();
  StreamController<LlmDownloadProgress>? _progress;
  bool _downloading = false;

  bool get isDownloading => _downloading;

  Future<File> fileFor(LlmModelInfo info) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return File(p.join(dir.path, info.fileName));
  }

  Future<bool> isDownloaded(LlmModelInfo info) async {
    final f = await fileFor(info);
    if (!await f.exists()) return false;
    final size = await f.length();
    return size > info.approxBytes ~/ 2;
  }

  Future<void> delete(LlmModelInfo info) async {
    final f = await fileFor(info);
    if (await f.exists()) await f.delete();
  }

  /// Start a download for [info]. Emits progress until completion. Throws
  /// on non-200 response or network failure; the partial file is removed.
  Stream<LlmDownloadProgress> download(LlmModelInfo info) {
    if (_downloading) {
      return Stream.error(StateError('A download is already in progress.'));
    }
    _downloading = true;
    _progress = StreamController<LlmDownloadProgress>.broadcast();
    _run(info);
    return _progress!.stream;
  }

  Future<void> _run(LlmModelInfo info) async {
    final tempFile = (await fileFor(info))
        .parent
        .uri
        .resolve('${info.fileName}.part')
        .toFilePath();
    final partial = File(tempFile);
    IOSink? sink;
    try {
      if (await partial.exists()) await partial.delete();
      final req = http.Request('GET', Uri.parse(info.downloadUrl));
      final resp = await _client.send(req);
      if (resp.statusCode != 200) {
        throw HttpException(
            'Download failed (${resp.statusCode}) for ${info.downloadUrl}');
      }
      final total = resp.contentLength ?? info.approxBytes;
      var received = 0;
      sink = partial.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        _progress?.add(LlmDownloadProgress(
            receivedBytes: received, totalBytes: total));
      }
      await sink.flush();
      await sink.close();
      sink = null;
      final dest = await fileFor(info);
      if (await dest.exists()) await dest.delete();
      await partial.rename(dest.path);
      await _progress?.close();
    } catch (e, st) {
      try {
        await sink?.close();
      } catch (_) {}
      if (await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
      _progress?.addError(e, st);
      await _progress?.close();
    } finally {
      _downloading = false;
      _progress = null;
    }
  }
}
