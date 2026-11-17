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

    final db = await databaseFactory.openDatabase(path, options: OpenDatabaseOptions(
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    ));
    await _ensureStandaloneExpenseTables(db);
    return db;
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _ensureStandaloneExpenseTables(db);
    }
  }

  Future<void> _ensureStandaloneExpenseTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS standalone_expense_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        icon_name TEXT DEFAULT 'category',
        color_hex TEXT DEFAULT '#1976D2',
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS standalone_expenses (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('CREDIT', 'DEBIT')),
        amount REAL NOT NULL CHECK(amount > 0),
        payment_mode TEXT NOT NULL DEFAULT 'CASH',
        note TEXT,
        expense_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES standalone_expense_categories(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_st_expenses_date ON standalone_expenses(expense_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_st_expenses_cat ON standalone_expenses(category_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_st_expenses_type ON standalone_expenses(type)
    ''');

    // Seed default categories if table is empty
    final countRes = await db.rawQuery('SELECT COUNT(*) as count FROM standalone_expense_categories');
    final count = (countRes.isNotEmpty && countRes.first['count'] != null)
        ? (countRes.first['count'] as num).toInt()
        : 0;
    if (count == 0) {
      final now = DateTime.now().toIso8601String();
      final defaults = [
        {'id': 'cat_tea', 'name': 'Tea & Snacks (ચા-નાસ્તો)', 'icon_name': 'local_cafe', 'color_hex': '#FF7043', 'is_default': 1, 'created_at': now},
        {'id': 'cat_rent', 'name': 'Shop Rent (દુકાન ભાડું)', 'icon_name': 'storefront', 'color_hex': '#5C6BC0', 'is_default': 1, 'created_at': now},
        {'id': 'cat_electricity', 'name': 'Electricity Bill (લાઈટ બિલ)', 'icon_name': 'bolt', 'color_hex': '#FBC02D', 'is_default': 1, 'created_at': now},
        {'id': 'cat_salary', 'name': 'Staff Salary (પગાર)', 'icon_name': 'badge', 'color_hex': '#00897B', 'is_default': 1, 'created_at': now},
        {'id': 'cat_transport', 'name': 'Transport (ભાડું / ટ્રાન્સપોર્ટ)', 'icon_name': 'local_shipping', 'color_hex': '#8D6E63', 'is_default': 1, 'created_at': now},
        {'id': 'cat_repairs', 'name': 'Repairs & Maintenance (રિપેરિંગ)', 'icon_name': 'build', 'color_hex': '#78909C', 'is_default': 1, 'created_at': now},
        {'id': 'cat_supplier', 'name': 'Supplier Payment (વેપારી ચુકવણી)', 'icon_name': 'account_balance', 'color_hex': '#8E24AA', 'is_default': 1, 'created_at': now},
        {'id': 'cat_capital', 'name': 'Personal / Owner Capital (માલિકની મૂડી)', 'icon_name': 'account_balance_wallet', 'color_hex': '#2E7D32', 'is_default': 1, 'created_at': now},
        {'id': 'cat_refund', 'name': 'Refund Received (રીફંડ)', 'icon_name': 'assignment_return', 'color_hex': '#0288D1', 'is_default': 1, 'created_at': now},
        {'id': 'cat_other_income', 'name': 'Other Income (અન્ય આવક)', 'icon_name': 'savings', 'color_hex': '#43A047', 'is_default': 1, 'created_at': now},
      ];
      for (final cat in defaults) {
        await db.insert('standalone_expense_categories', cat, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
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

  Future<void> incrementQueueAttempts(int id) async {
    final db = await instance.database;
    if (db == null) return;
    await db.rawUpdate('UPDATE sync_queue SET attempts = COALESCE(attempts, 0) + 1 WHERE id = ?', [id]);
  }

  Future<void> clearAllData({bool preserveSyncQueue = true}) async {
    final db = await instance.database;
    if (db == null) return;
    await db.delete('shop_data');
    await db.delete('items');
    await db.delete('tokens');
    await db.delete('customers');
    if (!preserveSyncQueue) {
      await db.delete('sync_queue');
    }
  }

  // --- Standalone Expense Categories ---
  Future<List<Map<String, dynamic>>> getStandaloneCategories() async {
    final db = await instance.database;
    if (db == null) return [];
    return await db.query('standalone_expense_categories', orderBy: 'is_default DESC, name ASC');
  }

  Future<void> insertStandaloneCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    if (db == null) return;
    await db.insert('standalone_expense_categories', category, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStandaloneCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    if (db == null) return;
    await db.update(
      'standalone_expense_categories',
      category,
      where: 'id = ?',
      whereArgs: [category['id']],
    );
  }

  Future<void> deleteStandaloneCategory(String id) async {
    final db = await instance.database;
    if (db == null) return;
    await db.delete('standalone_expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Standalone Expenses ---
  Future<void> insertStandaloneExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    if (db == null) return;
    await db.insert('standalone_expenses', expense, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStandaloneExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    if (db == null) return;
    await db.update(
      'standalone_expenses',
      expense,
      where: 'id = ?',
      whereArgs: [expense['id']],
    );
  }

  Future<void> deleteStandaloneExpense(String id) async {
    final db = await instance.database;
    if (db == null) return;
    await db.delete('standalone_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getStandaloneExpenses({
    String? startDate,
    String? endDate,
    String? categoryId,
    String? type,
    String? search,
  }) async {
    final db = await instance.database;
    if (db == null) return [];

    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (startDate != null && startDate.isNotEmpty) {
      whereClauses.add('expense_date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      whereClauses.add('expense_date <= ?');
      whereArgs.add(endDate);
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      whereClauses.add('category_id = ?');
      whereArgs.add(categoryId);
    }
    if (type != null && type.isNotEmpty && type != 'ALL') {
      whereClauses.add('type = ?');
      whereArgs.add(type.toUpperCase());
    }
    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(category_name LIKE ? OR note LIKE ?)');
      whereArgs
        ..add('%${search.trim()}%')
        ..add('%${search.trim()}%');
    }

    final where = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;
    return await db.query(
      'standalone_expenses',
      where: where,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'expense_date DESC, created_at DESC',
    );
  }

  Future<Map<String, double>> getStandaloneExpenseSummary({
    String? startDate,
    String? endDate,
  }) async {
    final db = await instance.database;
    if (db == null) return {'credit': 0.0, 'debit': 0.0, 'net': 0.0};

    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (startDate != null && startDate.isNotEmpty) {
      whereClauses.add('expense_date >= ?');
      whereArgs.add(startDate);
    }
    if (endDate != null && endDate.isNotEmpty) {
      whereClauses.add('expense_date <= ?');
      whereArgs.add(endDate);
    }

    final where = whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';

    final res = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type = 'CREDIT' THEN amount ELSE 0 END) as total_credit,
        SUM(CASE WHEN type = 'DEBIT' THEN amount ELSE 0 END) as total_debit
      FROM standalone_expenses
      $where
    ''', whereArgs);

    if (res.isNotEmpty) {
      final totalCredit = (res.first['total_credit'] as num?)?.toDouble() ?? 0.0;
      final totalDebit = (res.first['total_debit'] as num?)?.toDouble() ?? 0.0;
      return {
        'credit': totalCredit,
        'debit': totalDebit,
        'net': totalCredit - totalDebit,
      };
    }
    return {'credit': 0.0, 'debit': 0.0, 'net': 0.0};
  }
}

