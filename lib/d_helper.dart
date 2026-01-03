import 'dart:developer';

import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DBHelper {
  static Database? _db;


  /// Get database instance ---------------
  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDB();
    return _db!;
  }

  static Future<int> insertItem({
    required String name,
    required String age,
    required String category,
  }) async {
    final db = await database;
    return await db.insert('items', {
      'name': name,
      'age': age,
      'category': category,
    });
  }

  static Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    return await db.query('items');
  }

  static Future<int> clearItems() async {
    final db = await database;
    return await db.delete('items');
  }

  static void closeDB() async {
    final db = await database;
    await db.close();
    log("--db.close()--${db.isOpen}");
  }

  static Future<Database> openDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'secure.db');
    _db = await openDatabase(
      path,
      password: "12345",
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            age TEXT,
            category TEXT
          )
        ''');
      },
    );
    log("----$_db");
    return _db!;
  }
}
