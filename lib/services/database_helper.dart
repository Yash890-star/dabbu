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

    return await openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Create Goals Table
      await db.execute('''
        CREATE TABLE goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          targetAmount REAL NOT NULL,
          savedAmount REAL DEFAULT 0.0,
          deadline INTEGER,
          color INTEGER,
          icon TEXT
        )
      ''');

      // 2. Add goalId to transactions
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN goalId INTEGER REFERENCES goals(id)',
        );
      } catch (e) {
        // Column might already exist if we are in a weird state, ignore
        // print("Column goalId might already exist: $e");
      }
    }

    if (oldVersion < 3) {
      // 3. Add isArchived to goals
      try {
        await db.execute(
          'ALTER TABLE goals ADD COLUMN isArchived INTEGER DEFAULT 0',
        );
      } catch (e) {
        // print("Column isArchived might already exist: $e");
      }
    }

    if (oldVersion < 4) {
      // 4. Subscriptions Table
      await db.execute('''
        CREATE TABLE subscriptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount REAL NOT NULL,
          sender TEXT,
          period INTEGER DEFAULT 30,
          nextBillDate INTEGER,
          patternId INTEGER,
          isActive INTEGER DEFAULT 1,
          FOREIGN KEY (patternId) REFERENCES patterns (id)
        )
      ''');
    }

    if (oldVersion < 5) {
      // 5. Add Index on Date for transactions table
      await db.execute(
        'CREATE INDEX idx_transactions_date ON transactions (date)',
      );
    }

    if (oldVersion < 6) {
      // 6. Add is_goal_addition to transactions
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN is_goal_addition INTEGER DEFAULT 1',
        );
      } catch (e) {
        // print("Column is_goal_addition might already exist: $e");
      }
    }

    if (oldVersion < 7) {
      // 7. Budget Overrides (Historic Budgets)
      // categoryId = 0 implies Total Monthly Budget
      await db.execute('''
        CREATE TABLE budget_overrides (
          month INTEGER,
          year INTEGER,
          categoryId INTEGER, 
          amount REAL,
          PRIMARY KEY (month, year, categoryId)
        )
      ''');
    }
    if (oldVersion < 8) {
      // 8. Subscription Frequency Details
      try {
        await db.execute(
          'ALTER TABLE subscriptions ADD COLUMN frequencyType TEXT DEFAULT "MONTH"',
        );
        await db.execute(
          'ALTER TABLE subscriptions ADD COLUMN frequencyValue INTEGER DEFAULT 1',
        );

        // Migrate existing data
        // Assume period=30 is MONTHLY (1 Month)
        // Assume anything else is DAYS
        await db.execute('''
          UPDATE subscriptions 
          SET frequencyType = 'MONTH', frequencyValue = 1 
          WHERE period = 30
        ''');

        await db.execute('''
          UPDATE subscriptions 
          SET frequencyType = 'DAY', frequencyValue = period 
          WHERE period != 30
        ''');
      } catch (e) {
        // Ignore if columns exist
      }
    }

    if (oldVersion < 9) {
      // 9. Ignore Transaction Flag
      try {
        await db.execute(
          'ALTER TABLE transactions ADD COLUMN isIgnored INTEGER DEFAULT 0',
        );
      } catch (e) {
        // Ignore if column exists
      }
    }
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
        goalId INTEGER,
        is_goal_addition INTEGER DEFAULT 1,
        isIgnored INTEGER DEFAULT 0, -- New column
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (patternId) REFERENCES patterns (id),
        FOREIGN KEY (goalId) REFERENCES goals (id)
      )
    ''');

    // 4. Goals Table
    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        savedAmount REAL DEFAULT 0.0,
        deadline INTEGER,
        color INTEGER,
        icon TEXT,
        isArchived INTEGER DEFAULT 0
      )
    ''');

    // 5. Subscriptions Table
    await db.execute('''
      CREATE TABLE subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        sender TEXT,
        period INTEGER DEFAULT 30, -- Legacy/Fallback
        frequencyType TEXT DEFAULT 'MONTH', -- DAY, WEEK, MONTH, YEAR
        frequencyValue INTEGER DEFAULT 1,
        nextBillDate INTEGER,
        patternId INTEGER,
        isActive INTEGER DEFAULT 1,
        FOREIGN KEY (patternId) REFERENCES patterns (id)
      )
    ''');

    // 6. Budget Overrides Table
    await db.execute('''
      CREATE TABLE budget_overrides (
        month INTEGER,
        year INTEGER,
        categoryId INTEGER, 
        amount REAL,
        PRIMARY KEY (month, year, categoryId)
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

    // Sanitize: only allow valid columns
    final validColumns = [
      'amount',
      'sender',
      'body',
      'date',
      'type',
      'categoryId',
      'patternId',
      'goalId',
      'goalId',
      'is_goal_addition',
      'isIgnored',
    ];
    final Map<String, dynamic> sanitized = {};
    for (var key in validColumns) {
      if (row.containsKey(key)) sanitized[key] = row[key];
    }

    return await db.update(
      'transactions',
      sanitized,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getTransactionsWithDetails({
    int limit = 0,
  }) async {
    final db = await instance.database;

    // We perform a LEFT JOIN on both Categories and Patterns
    // This gives us the Category Name (e.g. "Food") and Pattern Name (e.g. "HDFC CC")
    String query = '''
      SELECT 
        t.id, 
        t.amount, 
        t.sender, 
        t.body, 
        t.date, 
        t.type, 
        t.categoryId, 
        t.patternId,
        t.goalId,
        t.goalId,
        t.is_goal_addition,
        t.isIgnored,
        c.name as categoryName, 
        c.color as categoryColor, 
        c.icon as categoryIcon,
        p.name as patternName,
        g.name as goalName
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      LEFT JOIN patterns p ON t.patternId = p.id
      LEFT JOIN goals g ON t.goalId = g.id
      ORDER BY t.date DESC
    ''';

    if (limit > 0) {
      query += ' LIMIT $limit';
    }

    return await db.rawQuery(query);
  }
  // Inside DatabaseHelper class

  Future<List<Map<String, dynamic>>> getFilteredTransactions({
    int? startEpoch, // Start Date timestamp
    int? endEpoch, // End Date timestamp
    List<int>? categoryIds, // Multi-select Category Filter
    List<int>? patternIds, // Multi-select Payment Method Filter
    String? type, // 'debit' or 'credit'
    int? goalId, // Filter by Goal
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

    if (type != null) {
      conditions.add('t.type = ?');
      args.add(type);
    }

    if (goalId != null) {
      conditions.add('t.goalId = ?');
      args.add(goalId);
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
  // --- Goals CRUD ---

  Future<int> createGoal(Map<String, dynamic> goal) async {
    final db = await instance.database;
    return await db.insert('goals', goal);
  }

  Future<List<Map<String, dynamic>>> getAllGoals() async {
    final db = await instance.database;
    // Calculate savedAmount dynamically from transactions
    final goals = await db.query('goals');
    final List<Map<String, dynamic>> enrichedGoals = [];

    for (var goal in goals) {
      final id = goal['id'] as int;
      final result = await db.rawQuery(
        '''SELECT SUM(
             CASE 
               WHEN is_goal_addition = 1 THEN amount 
               ELSE -amount 
             END
           ) as total 
           FROM transactions WHERE goalId = ?''',
        [id],
      );
      final double totalSaved =
          (result.first['total'] as num?)?.toDouble() ?? 0.0;

      final Map<String, dynamic> newGoal = Map.from(goal);
      newGoal['savedAmount'] = totalSaved;
      enrichedGoals.add(newGoal);
    }
    return enrichedGoals;
  }

  Future<int> updateGoal(Map<String, dynamic> goal) async {
    final db = await instance.database;
    final id = goal['id'];
    return await db.update('goals', goal, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteGoal(int id) async {
    final db = await instance.database;
    // 1. Unlink transactions
    await db.update(
      'transactions',
      {'goalId': null},
      where: 'goalId = ?',
      whereArgs: [id],
    );
    // 2. Delete goal
    return await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archiveGoal(int id, bool isArchived) async {
    final db = await instance.database;
    await db.update(
      'goals',
      {'isArchived': isArchived ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Subscriptions CRUD ---
  Future<int> createSubscription(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('subscriptions', row);
  }

  Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    final db = await instance.database;
    return await db.query('subscriptions', orderBy: 'nextBillDate ASC');
  }

  Future<int> updateSubscription(Map<String, dynamic> row) async {
    final db = await instance.database;
    final id = row['id'];
    return await db.update(
      'subscriptions',
      row,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSubscription(int id) async {
    final db = await instance.database;
    return await db.delete('subscriptions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    final db = await instance.database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    // Calculate end date (first day of next month)
    final end =
        (month == 12)
            ? DateTime(year + 1, 1, 1).millisecondsSinceEpoch
            : DateTime(year, month + 1, 1).millisecondsSinceEpoch;

    // Use raw query for efficiency
    // We treat 'debit' and 'expense' as Spend, 'credit' and 'income' as Income
    final result = await db.rawQuery(
      '''
      SELECT 
        SUM(CASE WHEN type IN ('debit', 'expense') THEN amount ELSE 0 END) as expense,
        SUM(CASE WHEN type IN ('credit', 'income') THEN amount ELSE 0 END) as income
      FROM transactions 
      WHERE date >= ? AND date < ? AND (isIgnored IS NULL OR isIgnored = 0)
    ''',
      [start, end],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'expense': (row['expense'] as num?)?.toDouble() ?? 0.0,
        'income': (row['income'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return {'expense': 0.0, 'income': 0.0};
  }

  // --- Monthly Budget Overrides ---

  Future<void> setMonthBudget({
    required int month,
    required int year,
    required double amount,
    int categoryId = 0, // 0 = Total, >0 = Category
  }) async {
    final db = await instance.database;
    await db.insert('budget_overrides', {
      'month': month,
      'year': year,
      'categoryId': categoryId,
      'amount': amount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns a map where key 'total' is the monthly budget,
  /// and 'cat_ID' are category budgets.
  /// If no entry exists for a month, it returns empty map.
  Future<Map<String, double>> getMonthBudgets(int month, int year) async {
    final db = await instance.database;
    final res = await db.query(
      'budget_overrides',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );

    final Map<String, double> budgets = {};
    for (var row in res) {
      final catId = row['categoryId'] as int;
      final amount = (row['amount'] as num).toDouble();
      if (catId == 0) {
        budgets['total'] = amount;
      } else {
        budgets['cat_$catId'] = amount;
      }
    }
    return budgets;
  }
}
