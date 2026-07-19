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
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE pantry_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            brand TEXT,
            barcode TEXT,
            category TEXT NOT NULL,
            quantity REAL,
            unit TEXT,
            expiry_date TEXT,
            added_at TEXT NOT NULL,
            notes TEXT,
            image_url TEXT
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_pantry_expiry ON pantry_items(expiry_date)');
        await db.execute(
            'CREATE INDEX idx_pantry_barcode ON pantry_items(barcode)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE pantry_items ADD COLUMN image_url TEXT');
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

  Future<List<PantryItem>> all() async {
    final db = await _database;
    final rows = await db.query(
      'pantry_items',
      orderBy:
          "CASE WHEN expiry_date IS NULL THEN 1 ELSE 0 END, expiry_date ASC, name ASC",
    );
    return rows.map(PantryItem.fromMap).toList();
  }

  Future<PantryItem?> findByBarcode(String barcode) async {
    final db = await _database;
    final rows = await db.query(
      'pantry_items',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PantryItem.fromMap(rows.first);
  }
}
