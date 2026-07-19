import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProductImageCache {
  ProductImageCache._();
  static final ProductImageCache instance = ProductImageCache._();

  Directory? _dir;

  Future<Directory> _imageDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'product_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<String?> download(String barcode, String remoteUrl) async {
    try {
      final dir = await _imageDir();
      final safe = barcode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final ext = _extOf(remoteUrl);
      final file = File(p.join(dir.path, '$safe$ext'));
      final resp = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteAt(String? path) async {
    if (path == null || path.isEmpty) return;
    if (isRemote(path)) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static bool isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  static String _extOf(String url) {
    final ext = p.extension(Uri.parse(url).path).toLowerCase();
    if (ext.isEmpty || ext.length > 5) return '.jpg';
    return ext;
  }
}
