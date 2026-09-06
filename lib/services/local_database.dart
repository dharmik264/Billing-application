import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;
  bool _isInitialized = false;

  LocalDatabase._init();

  Future<Database?> get database async {
    if (kIsWeb) return null; // SQLite is not directly supported on web here
    if (_database != null) return _database!;
    
    _database = await _initDB('local_billing.db');
    return _database;
  }

  Future<Database> _initDB(String filePath) async {
    if (!_isInitialized) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      _isInitialized = true;
    }
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(
      version: 1,
      onCreate: _createDB,
    ));
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE shop_data (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE tokens (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        status TEXT,
        created_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        name TEXT,
        phone TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER DEFAULT 0
      )
    ''');
  }

  // --- Shop Data ---
  Future<void> saveShopData(Map<String, dynamic> data) async {
    final db = await instance.database;
    if (db == null) return;
    await db.insert('shop_data', {'id': 'current', 'data': jsonEncode(data)}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getShopData() async {
    final db = await instance.database;
    if (db == null) return null;
    final res = await db.query('shop_data', where: 'id = ?', whereArgs: ['current']);
    if (res.isNotEmpty) {
      return jsonDecode(res.first['data'] as String);
    }
    return null;
  }
  
  // --- Items ---
  Future<void> saveItems(List<Map<String, dynamic>> items) async {
    final db = await instance.database;
    if (db == null) return;
    Batch batch = db.batch();
    await db.delete('items');
    for (var item in items) {
      final id = item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      item['id'] = id;
      batch.insert('items', {'id': id, 'data': jsonEncode(item)}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> saveItem(Map<String, dynamic> item) async {
    final db = await instance.database;
    if (db == null) return;
    final id = item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    item['id'] = id;
    await db.insert('items', {'id': id, 'data': jsonEncode(item)}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  Future<List<Map<String, dynamic>>> getItems() async {
    final db = await instance.database;
    if (db == null) return [];
    final res = await db.query('items');
    return res.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }

  Future<void> deleteItem(String id) async {
    final db = await instance.database;
    if (db == null) return;
    await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  // --- Tokens ---
  Future<void> saveTokens(List<Map<String, dynamic>> tokens) async {
    final db = await instance.database;
    if (db == null) return;
    Batch batch = db.batch();
    for (var token in tokens) {
      final id = token['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      token['id'] = id;
      batch.insert('tokens', {
        'id': id, 
        'data': jsonEncode(token),
        'status': token['status']?.toString() ?? 'completed',
        'created_at': token['createdAt']?.toString() ?? token['created_at']?.toString() ?? DateTime.now().toIso8601String()
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> saveToken(Map<String, dynamic> token) async {
    final db = await instance.database;
    if (db == null) return;
    final id = token['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    token['id'] = id;
    await db.insert('tokens', {
        'id': id, 
        'data': jsonEncode(token),
        'status': token['status']?.toString() ?? 'completed',
        'created_at': token['createdAt']?.toString() ?? token['created_at']?.toString() ?? DateTime.now().toIso8601String()
      }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getTokens({int? limit}) async {
    final db = await instance.database;
    if (db == null) return [];
    final res = await db.query('tokens', orderBy: 'created_at DESC', limit: limit);
    return res.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }
  
  Future<void> deleteToken(String id) async {
    final db = await instance.database;
    if (db == null) return;
    await db.delete('tokens', where: 'id = ?', whereArgs: [id]);
  }

  // --- Customers ---
  Future<void> saveCustomers(List<Map<String, dynamic>> customers) async {
    final db = await instance.database;
    if (db == null) return;
    Batch batch = db.batch();
    for (var customer in customers) {
      final id = customer['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      customer['id'] = id;
      batch.insert('customers', {
        'id': id, 
        'data': jsonEncode(customer),
        'name': customer['name']?.toString() ?? '',
        'phone': customer['phone']?.toString() ?? ''
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<void> saveCustomer(Map<String, dynamic> customer) async {
    final db = await instance.database;
    if (db == null) return;
    final id = customer['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    customer['id'] = id;
    await db.insert('customers', {
      'id': id, 
      'data': jsonEncode(customer),
      'name': customer['name']?.toString() ?? '',
      'phone': customer['phone']?.toString() ?? ''
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCustomers({String? search}) async {
    final db = await instance.database;
    if (db == null) return [];
    List<Map<String, Object?>> res;
    if (search != null && search.isNotEmpty) {
      res = await db.query('customers', where: 'name LIKE ? OR phone LIKE ?', whereArgs: ['%$search%', '%$search%']);
    } else {
      res = await db.query('customers');
    }
    return res.map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>).toList();
  }
  
  Future<void> deleteCustomer(String id) async {
    final db = await instance.database;
    if (db == null) return;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // --- Sync Queue ---
  Future<void> addToQueue(String endpoint, String method, Map<String, dynamic> body) async {
    final db = await instance.database;
    if (db == null) return;
    await db.insert('sync_queue', {
      'endpoint': endpoint,
      'method': method,
      'body': jsonEncode(body),
      'created_at': DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String, dynamic>>> getQueue() async {
    final db = await instance.database;
    if (db == null) return [];
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  Future<void> removeFromQueue(int id) async {
    final db = await instance.database;
    if (db == null) return;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
