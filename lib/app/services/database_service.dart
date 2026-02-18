import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sub.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'subs';

  // Singleton pattern
  static DatabaseService? _instance;
  DatabaseService._();
  
  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  // Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'sub3_database.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create table
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subPath1 TEXT NOT NULL,
        mp3Path TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // Save Sub object to database
  Future<int> saveSub(Sub sub) async {
    final db = await database;
    
    final data = sub.toMap();
    data['createdAt'] = DateTime.now().toIso8601String();
    data.remove('id'); // Remove id for auto-increment

    return await db.insert(_tableName, data);
  }

  // Get all Sub objects from database
  Future<List<Sub>> getAllSubs() async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => Sub.fromMap(map)).toList();
  }

  // Get Sub by ID
  Future<Sub?> getSubById(int id) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Sub.fromMap(maps[0]);
    }
    return null;
  }

  // Update Sub object
  Future<int> updateSub(int id, Sub sub) async {
    final db = await database;
    
    final data = sub.toMap();
    data.remove('id'); // Remove id for update

    return await db.update(
      _tableName,
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete Sub object
  Future<int> deleteSub(int id) async {
    final db = await database;
    
    return await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete all Sub objects
  Future<int> deleteAllSubs() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
} 