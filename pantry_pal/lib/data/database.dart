import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/pantry_item.dart';

class PantryDatabase {
  PantryDatabase._();
  static final PantryDatabase instance = PantryDatabase._();

  Database? _db;

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'pantry.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pantry_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            gtin TEXT,
            name TEXT NOT NULL,
            brand TEXT,
            category TEXT NOT NULL,
            quantity REAL,
            unit TEXT,
            expiry_date TEXT,
            expiry_is_exact INTEGER NOT NULL DEFAULT 1,
            added_date TEXT NOT NULL,
            consumed INTEGER NOT NULL DEFAULT 0,
            notes TEXT,
            image_url TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_pantry_expiry ON pantry_items(expiry_date)');
        await db.execute('CREATE INDEX idx_pantry_gtin ON pantry_items(gtin)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE pantry_items ADD COLUMN image_url TEXT');
        }
        if (oldVersion < 3) {
          // Align with the spec schema: rename columns and add the
          // exact-vs-estimated expiry flag and the consumed flag.
          await db.execute(
              'ALTER TABLE pantry_items RENAME COLUMN barcode TO gtin');
          await db.execute(
              'ALTER TABLE pantry_items RENAME COLUMN added_at TO added_date');
          await db.execute(
              'ALTER TABLE pantry_items ADD COLUMN expiry_is_exact INTEGER NOT NULL DEFAULT 1');
          await db.execute(
              'ALTER TABLE pantry_items ADD COLUMN consumed INTEGER NOT NULL DEFAULT 0');
          await db.execute('DROP INDEX IF EXISTS idx_pantry_barcode');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_pantry_gtin ON pantry_items(gtin)');
        }
      },
    );
  }

  Future<int> insert(PantryItem item) async {
    final db = await _database;
    final map = item.toMap()..remove('id');
    return db.insert('pantry_items', map);
  }

  Future<int> update(PantryItem item) async {
    final db = await _database;
    return db.update(
      'pantry_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _database;
    return db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
  }

  /// Marks an item used-up (or un-marks it). Consumed items are kept for history
  /// but excluded from the active pantry list.
  Future<int> setConsumed(int id, bool consumed) async {
    final db = await _database;
    return db.update(
      'pantry_items',
      {'consumed': consumed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Active (not consumed) items, soonest expiry first, undated items last.
  Future<List<PantryItem>> all() async {
    final db = await _database;
    final rows = await db.query(
      'pantry_items',
      where: 'consumed = 0',
      orderBy:
          "CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END, expiry_date ASC, name ASC",
    );
    return rows.map(PantryItem.fromMap).toList();
  }

  Future<PantryItem?> findByGtin(String gtin) async {
    final db = await _database;
    final rows = await db.query(
      'pantry_items',
      where: 'gtin = ? AND consumed = 0',
      whereArgs: [gtin],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PantryItem.fromMap(rows.first);
  }
}
