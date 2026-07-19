import 'dart:async';

import 'package:flutter/material.dart';

import '../services/llm_model_manager.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _model = kDefaultModel;
  bool _downloaded = false;
  bool _busy = false;
  String? _error;
  StreamSubscription<LlmDownloadProgress>? _progressSub;
  LlmDownloadProgress? _progress;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final ok = await LlmModelManager.instance.isDownloaded(_model);
    if (!mounted) return;
    setState(() {
      _downloaded = ok;
    });
  }

  void _startDownload() {
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    final stream = LlmModelManager.instance.download(_model);
    _progressSub = stream.listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      },
      onDone: () async {
        if (!mounted) return;
        setState(() => _busy = false);
        await _refresh();
      },
    );
  }

  Future<void> _delete() async {
    await LlmModelManager.instance.delete(_model);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_model.displayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    '${(_model.approxBytes / (1024 * 1024)).round()} MB · stored on device',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  if (_busy && progress != null) ...[
                    LinearProgressIndicator(value: progress.fraction),
                    const SizedBox(height: 6),
                    Text(
                      '${(progress.fraction * 100).toStringAsFixed(0)}%  ·  '
                      '${(progress.receivedBytes / (1024 * 1024)).toStringAsFixed(1)} '
                      '/ ${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ] else if (_downloaded) ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.green.shade600, size: 18),
                        const SizedBox(width: 6),
                        const Text('Installed'),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Not downloaded. Use Wi-Fi — this is a ~'
                      '${(_model.approxBytes / (1024 * 1024)).round()} MB file.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(color: Colors.red.shade700)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_downloaded && !_busy)
                        TextButton.icon(
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _busy || _downloaded ? null : _startDownload,
                        icon: const Icon(Icons.download),
                        label: Text(_downloaded ? 'Installed' : 'Download'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'When installed, recipe suggestions are generated on-device — no '
            'network calls. This is a very small model (~270 MB) so quality is '
            'modest; suggestions fall back to templates when output is unusable.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
