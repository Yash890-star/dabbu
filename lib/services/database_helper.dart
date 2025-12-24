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
        color INTEGER,
        budgetLimit REAL DEFAULT 0.0
      )
    ''');

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

    // Insert default categories
    await _insertDefaultCategories(db);
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final batch = db.batch();

    // 1. Uncategorized (Mandatory)
    batch.insert('categories', {
      'name': 'Uncategorized',
      'icon': 'help_outline',
      'color': 0xFF9E9E9E, // Grey
    });

    // 2. Common Defaults
    final defaults = [
      {
        'name': 'Food & Dining',
        'icon': 'fastfood',
        'color': 0xFFEF6C00,
      }, // Orange
      {
        'name': 'Transportation',
        'icon': 'directions_car',
        'color': 0xFF1565C0,
      }, // Blue
      {
        'name': 'Shopping',
        'icon': 'shopping_bag',
        'color': 0xFF7B1FA2,
      }, // Purple
      {
        'name': 'Bills & Utilities',
        'icon': 'receipt',
        'color': 0xFFC62828,
      }, // Red
      {'name': 'Entertainment', 'icon': 'movie', 'color': 0xFF00695C}, // Teal
      {
        'name': 'Health & Fitness',
        'icon': 'medical_services',
        'color': 0xFF2E7D32,
      }, // Green
      {'name': 'Travel', 'icon': 'flight', 'color': 0xFF0277BD}, // Light Blue
      {'name': 'Education', 'icon': 'school', 'color': 0xFFF9A825}, // Yellow
    ];

    for (var cat in defaults) {
      batch.insert('categories', cat);
    }

    await batch.commit();
  }

  // Callable helper to seed defaults if missing (for existing users)
  Future<void> seedDefaultCategories() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );

    if (count != null && count <= 1) {
      // Only Uncategorized exists
      // We manually insert the others (excluding Uncategorized which ID 1 usually is)
      final defaults = [
        {'name': 'Food & Dining', 'icon': 'fastfood', 'color': 0xFFEF6C00},
        {
          'name': 'Transportation',
          'icon': 'directions_car',
          'color': 0xFF1565C0,
        },
        {'name': 'Shopping', 'icon': 'shopping_bag', 'color': 0xFF7B1FA2},
        {'name': 'Bills & Utilities', 'icon': 'receipt', 'color': 0xFFC62828},
        {'name': 'Entertainment', 'icon': 'movie', 'color': 0xFF00695C},
        {
          'name': 'Health & Fitness',
          'icon': 'medical_services',
          'color': 0xFF2E7D32,
        },
        {'name': 'Travel', 'icon': 'flight', 'color': 0xFF0277BD},
        {'name': 'Education', 'icon': 'school', 'color': 0xFFF9A825},
      ];

      final batch = db.batch();
      for (var cat in defaults) {
        batch.insert('categories', cat);
      }
      await batch.commit();
    }
  }

  // --- Category Methods ---

  Future<int> addCategory(
    String name, {
    String? icon,
    int? color,
    double? budget,
  }) async {
    final db = await instance.database;
    return await db.insert('categories', {
      'name': name,
      'icon': icon,
      'color': color,
      'budgetLimit': budget ?? 0.0,
    });
  }

  Future<int> updateCategory(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  Future<void> deleteCategory(int id) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Move transactions to 'Uncategorized' (ID 1)
      await txn.update(
        'transactions',
        {'categoryId': 1},
        where: 'categoryId = ?',
        whereArgs: [id],
      );

      // 2. Delete the category
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
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

  Future<int> updatePattern(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('patterns', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTransactionsByPatternId(int patternId) async {
    final db = await instance.database;
    await db.delete(
      'transactions',
      where: 'patternId = ?',
      whereArgs: [patternId],
    );
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
