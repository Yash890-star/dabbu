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

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
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
}
