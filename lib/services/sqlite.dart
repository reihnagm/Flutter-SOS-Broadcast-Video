import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqlite_api.dart';

class DBHelper {  
  static Future<Database> database() async {
    final dbPath = await sql.getDatabasesPath();
    return await sql.openDatabase(path.join(dbPath, 'sos.db'), onCreate: (db, version) => createDb(db), version: 1);
  }

  static Future<void> createDb(Database db) async {
    await db.execute("CREATE TABLE sos (id TEXT PRIMARY KEY, mediaUrl TEXT, msg TEXT, created_at)");
  }

  static Future<void> insert(String table, Map<String, Object> data) async {
    Database db = await DBHelper.database();
    await db.insert(table, data, conflictAlgorithm: sql.ConflictAlgorithm.replace);
  }

  static Future<void> update(String table, Map<String, Object> data) async {
    Database db = await DBHelper.database();
    await db.update(table, data, where: 'id = ?', whereArgs: [data["id"]], conflictAlgorithm: sql.ConflictAlgorithm.ignore);
  }

  static Future<void> delete(String table, String id) async {
    Database db = await DBHelper.database();
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> format(String table) async {
    Database db = await DBHelper.database();
    await db.delete(table);
  }
  
  static Future<List<Map<String, dynamic>>> fetchSos(BuildContext context) async {
    Database db = await DBHelper.database();
    return db.rawQuery("SELECT * FROM sos ORDER BY id ASC");
  }
}
