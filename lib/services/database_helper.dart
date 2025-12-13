import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';

class DatabaseHelper {

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'dabbu.db');
    log("Initializing db");
    return await openDatabase(path, version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE transactions (
            _id INTEGER PRIMARY KEY AUTOINCREMENT,
            cost INT NOT NULL,
            date DATETIME NOT NULL,
            month TEXT NOT NULL,
            year TEXT NOT NULL,
            type TEXT CHECK(type IN ('CREDITED', 'DEBITED')) NOT NULL,
            entity TEXT NOT NULL,
            bankName TEXT NOT NULL
          );
        ''');
        log("Created transactions table");
        db.execute('''
          CREATE TABLE regex (
            _regexid INTEGER PRIMARY KEY AUTOINCREMENT,
            bank TEXT NOT NULL,
            type TEXT CHECK(type IN ('CREDITED', 'DEBITED')) NOT NULL,
            regex TEXT NOT NULL
          );
        ''');
        log("Created regex table");
        db.execute('''
          CREATE TABLE banks (
            bankid INTEGER PRIMARY KEY AUTOINCREMENT,
            bankName TEXT NOT NULL,
            messageAddress TEXT NOT NULL
          )
        ''');
        log("Created banks table");
      }
    );
  }

}