import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dabbu.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT,  
        color INTEGER
      )
    ''');

    // Insert the ONE mandatory default category
    await db.insert('categories', {
      'name': 'Uncategorized',
      'icon': 'help_outline',
      'color': 0xFF9E9E9E, // Grey
    });

    // 2. Patterns Table (For Regex)
    await db.execute('''
      CREATE TABLE patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,                  -- e.g. "HDFC Credit Card"
        senderId TEXT NOT NULL,
        patternRegex TEXT NOT NULL,
        messageType TEXT NOT NULL,  -- "credit" or "debit"
        extractionIndex INTEGER DEFAULT 1
      )
    ''');

    // 3. Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        sender TEXT NOT NULL,
        body TEXT,
        date INTEGER NOT NULL,
        type TEXT NOT NULL,         
        categoryId INTEGER DEFAULT 1, -- Defaults to 'Uncategorized' (ID 1)
        patternId INTEGER,          
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (patternId) REFERENCES patterns (id)
      )
    ''');
  }

  // --- Category Methods ---

  Future<int> addCategory(String name, {String? icon, int? color}) async {
    final db = await instance.database;
    return await db.insert('categories', {
      'name': name,
      'icon': icon,
      'color': color,
    });
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  // --- Pattern & Transaction Methods ---

  Future<int> insertPattern(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('patterns', row);
  }

  Future<void> deletePattern(int id, {required bool deleteTransactions}) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      if (deleteTransactions) {
        // Option 1: Delete all transactions associated with this pattern
        await txn.delete(
          'transactions',
          where: 'patternId = ?',
          whereArgs: [id],
        );
      } else {
        // Option 2: Keep transactions, but unlink them (set patternId to NULL)
        // They will essentially become "Manually Added" or "Unknown Source"
        await txn.update(
          'transactions',
          {'patternId': null},
          where: 'patternId = ?',
          whereArgs: [id],
        );
      }
      // Finally, delete the pattern itself
      await txn.delete('patterns', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  Future<int> updateTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update(
      'transactions',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTransactionsWithDetails() async {
    final db = await instance.database;

    // We perform a LEFT JOIN on both Categories and Patterns
    // This gives us the Category Name (e.g. "Food") and Pattern Name (e.g. "HDFC CC")
    return await db.rawQuery('''
    SELECT 
      t.id, 
      t.amount, 
      t.sender, 
      t.body, 
      t.date, 
      t.type, 
      t.categoryId, 
      t.patternId,
      c.name as categoryName, 
      c.color as categoryColor, 
      c.icon as categoryIcon,
      p.name as patternName
    FROM transactions t
    LEFT JOIN categories c ON t.categoryId = c.id
    LEFT JOIN patterns p ON t.patternId = p.id
    ORDER BY t.date DESC
  ''');
  }
  // Inside DatabaseHelper class

  Future<List<Map<String, dynamic>>> getFilteredTransactions({
    int? startEpoch, // Start Date timestamp
    int? endEpoch, // End Date timestamp
    List<int>? categoryIds, // Multi-select Category Filter
    List<int>? patternIds, // Multi-select Payment Method Filter
  }) async {
    final db = await instance.database;

    // 1. Build Dynamic WHERE Clause
    List<String> conditions = [];
    List<dynamic> args = [];

    // Always true condition to simplify logic
    conditions.add('1=1');

    if (startEpoch != null) {
      conditions.add('t.date >= ?');
      args.add(startEpoch);
    }

    if (endEpoch != null) {
      conditions.add('t.date <= ?');
      args.add(endEpoch);
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      // Create a string of question marks: "?, ?, ?"
      final placeholders = List.filled(categoryIds.length, '?').join(', ');
      conditions.add('t.categoryId IN ($placeholders)');
      args.addAll(categoryIds);
    }

    if (patternIds != null && patternIds.isNotEmpty) {
      if (patternIds.contains(-1)) {
        // Handle "Manual Transactions" (-1)
        final dbIds = patternIds.where((id) => id != -1).toList();

        if (dbIds.isEmpty) {
          // ONLY Manual Transactions selected
          conditions.add('t.patternId IS NULL');
        } else {
          // BOTH Manual AND some Specific Patterns selected
          final placeholders = List.filled(dbIds.length, '?').join(', ');
          conditions.add(
            '(t.patternId IN ($placeholders) OR t.patternId IS NULL)',
          );
          args.addAll(dbIds);
        }
      } else {
        // Standard filter (Only Specific Patterns)
        final placeholders = List.filled(patternIds.length, '?').join(', ');
        conditions.add('t.patternId IN ($placeholders)');
        args.addAll(patternIds);
      }
    }

    // 2. Execute Query
    final whereString = conditions.join(' AND ');

    return await db.rawQuery('''
    SELECT 
      t.*, 
      c.name as categoryName, 
      c.color as categoryColor, 
      c.icon as categoryIcon,
      p.name as patternName,
      p.senderId as senderId
    FROM transactions t
    LEFT JOIN categories c ON t.categoryId = c.id
    LEFT JOIN patterns p ON t.patternId = p.id
    WHERE $whereString
    ORDER BY t.date DESC
  ''', args);
  }
}
