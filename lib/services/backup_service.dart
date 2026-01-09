import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  // keys for JSON
  static const String _kVersion = 'version';
  static const String _kTimestamp = 'timestamp';
  static const String _kBudget = 'monthly_budget';
  static const String _kCategories = 'categories';
  static const String _kPatterns = 'patterns';
  static const String _kRules = 'category_rules';
  static const String _kGoals = 'goals';

  /// Exports settings to a JSON file and prompts user to share/save it.
  Future<void> exportSettings(BuildContext context) async {
    try {
      final data = await _gatherData();
      final jsonString = jsonEncode(data);

      final directory = await getTemporaryDirectory();
      final fileName =
          'dabbu_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share the file
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Dabbu Settings Backup',
          sharePositionOrigin:
              box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      }
    } catch (e) {
      debugPrint("Export Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  /// Imports settings from a user-selected file.
  Future<bool> importSettings(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(jsonString);

        await _restoreData(data);
        return true;
      }
    } catch (e) {
      debugPrint("Import Error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> _gatherData() async {
    final db = DatabaseHelper.instance;
    final prefs = await SharedPreferences.getInstance();

    final budget = prefs.getDouble('monthly_budget') ?? 0.0;

    // Direct DB queries to ensure we get raw data
    final database = await db.database;
    final categories = await database.query('categories');
    final patterns = await database.query('patterns');

    // category_rules might fail if table doesn't exist yet (v11), but it should exist now
    List<Map<String, dynamic>> rules = [];
    try {
      rules = await database.query('category_rules');
    } catch (_) {}

    final goals = await database.query('goals');

    return {
      _kVersion: 1,
      _kTimestamp: DateTime.now().toIso8601String(),
      _kBudget: budget,
      _kCategories: categories,
      _kPatterns: patterns,
      _kRules: rules,
      _kGoals: goals,
    };
  }

  Future<void> _restoreData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Budget
    if (data.containsKey(_kBudget)) {
      final double budget = (data[_kBudget] as num).toDouble();
      if (budget > 0) {
        await prefs.setDouble('monthly_budget', budget);
      }
    }

    // 2. Categories
    if (data.containsKey(_kCategories)) {
      final List cats = data[_kCategories];
      for (var c in cats) {
        await _upsertCategory(c);
      }
    }

    // 3. Patterns
    if (data.containsKey(_kPatterns)) {
      final List pats = data[_kPatterns];
      for (var p in pats) {
        await _upsertPattern(p);
      }
    }

    // 4. Rules
    if (data.containsKey(_kRules)) {
      final List rules = data[_kRules];
      for (var r in rules) {
        await _upsertRule(r);
      }
    }

    // 5. Goals
    if (data.containsKey(_kGoals)) {
      final List goals = data[_kGoals];
      for (var g in goals) {
        await _upsertGoal(g);
      }
    }
  }

  Future<void> _upsertCategory(Map<String, dynamic> cat) async {
    final db = await DatabaseHelper.instance.database;
    final name = cat['name'] as String;

    final existing = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existing.isNotEmpty) {
      // Update existing
      await db.update(
        'categories',
        {
          'color': cat['color'],
          'budgetLimit': cat['budgetLimit'],
          'icon': cat['icon'],
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      // Insert new (let ID autoincrement to avoid conflicts, ignoring imported ID)
      await db.insert('categories', {
        'name': name,
        'color': cat['color'],
        'budgetLimit': cat['budgetLimit'],
        'icon': cat['icon'],
      });
    }
  }

  Future<void> _upsertPattern(Map<String, dynamic> pat) async {
    final db = await DatabaseHelper.instance.database;
    final sender = pat['senderId'] as String;
    // Export uses DB column name 'patternRegex', but code might have looked for 'regex'.
    final regex = (pat['patternRegex'] ?? pat['regex']) as String;

    // Try to match by sender AND regex to avoid duplicates
    final existing = await db.query(
      'patterns',
      where: 'senderId = ? AND patternRegex = ?',
      whereArgs: [sender, regex],
    );

    if (existing.isEmpty) {
      await db.insert('patterns', {
        'senderId': sender,
        'patternRegex': regex,
        'name': pat['name'],
        'messageType': pat['messageType'],
        'extractionIndex': pat['extractionIndex'],
        'isLiquid': pat['isLiquid'],
      });
    }
  }

  Future<void> _upsertRule(Map<String, dynamic> rule) async {
    final db = await DatabaseHelper.instance.database;
    final keyword = rule['keyword'] as String;

    final existing = await db.query(
      'category_rules',
      where: 'keyword = ?',
      whereArgs: [keyword],
    );

    if (existing.isEmpty) {
      await db.insert('category_rules', {
        'keyword': keyword,
        'categoryId': rule['categoryId'], // Same FK caveat
      });
    }
  }

  Future<void> _upsertGoal(Map<String, dynamic> goal) async {
    final db = await DatabaseHelper.instance.database;
    final name = goal['name'] as String;

    final existing = await db.query(
      'goals',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (existing.isEmpty) {
      await db.insert('goals', {
        'name': name,
        'targetAmount': goal['targetAmount'],
        'savedAmount': goal['savedAmount'],
        'deadline': goal['deadline'],
        'color': goal['color'],
        'icon': goal['icon'],
        'isArchived': goal['isArchived'],
      });
    } else {
      // Maybe update saved amount? Let's just update fields
      await db.update(
        'goals',
        {
          'targetAmount': goal['targetAmount'],
          'savedAmount': goal['savedAmount'],
          'deadline': goal['deadline'],
          'color': goal['color'],
          'icon': goal['icon'],
          'isArchived': goal['isArchived'],
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }
}
