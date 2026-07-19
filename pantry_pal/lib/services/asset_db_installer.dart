import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Copies the bundled, read-only databases (`products.db`, `recipes.db`) out of
/// the app bundle and into the app's databases directory on first launch.
///
/// The bundle itself is read-only, so sqflite can't open assets in place — we
/// copy them once. Everything here is local file I/O; no network access.
class AssetDbInstaller {
  AssetDbInstaller._();
  static final AssetDbInstaller instance = AssetDbInstaller._();

  static const _assets = ['products.db', 'recipes.db'];

  /// Absolute path to an installed bundled DB (valid after [install]).
  Future<String> pathFor(String fileName) async {
    final dir = await getDatabasesPath();
    return p.join(dir, fileName);
  }

  /// Copies any bundled DB that isn't on disk yet. Safe to call every launch:
  /// existing files are left untouched so app updates never clobber a newer
  /// bundled dump the user hasn't got, nor touch the separate user pantry DB.
  Future<void> install() async {
    final dir = await getDatabasesPath();
    await Directory(dir).create(recursive: true);
    for (final name in _assets) {
      final dest = File(p.join(dir, name));
      if (await dest.exists()) continue;
      final data = await rootBundle.load('assets/$name');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await dest.writeAsBytes(bytes, flush: true);
    }
  }
}
