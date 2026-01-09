import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../utils/app_colors.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  Map<String, dynamic> transaction = {};

  // State
  int selectedCategoryId = 1;
  String categoryName = "Uncategorized";
  int? selectedGoalId;
  String? goalName;
  bool isManual = false;
  bool isIgnored = false;
  bool isLiquid = true;
  bool isExcluded = false;

  // Data
  List<Map<String, dynamic>> allCategories = [];
  List<Map<String, dynamic>> allGoals = [];

  // Constants for Category Colors
  final List<Color> categoryColors = AppColors.categoryColors;

  void init(Map<String, dynamic> initialTransaction) {
    transaction = Map<String, dynamic>.from(initialTransaction);

    selectedCategoryId = transaction['categoryId'] ?? 1;
    categoryName = transaction['categoryName'] ?? "Uncategorized";
    selectedGoalId = transaction['goalId'];
    isManual = transaction['patternId'] == null;
    isManual = transaction['patternId'] == null;
    isIgnored = (transaction['isIgnored'] as int? ?? 0) == 1;
    isLiquid = (transaction['isLiquid'] as int? ?? 1) == 1;
    isExcluded = (transaction['isExcluded'] as int? ?? 0) == 1;

    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await DatabaseHelper.instance.getCategories();
    final goals = await DatabaseHelper.instance.getAllGoals();

    allCategories = cats;
    allGoals = goals;

    if (selectedGoalId != null) {
      final found = goals.where((g) => g['id'] == selectedGoalId).firstOrNull;
      goalName = found?['name'];
    }

    notifyListeners();
  }

  Future<void> updateCategory(int newCatId, String newCatName) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      {'categoryId': newCatId},
      where: 'id = ?',
      whereArgs: [transaction['id']],
    );

    selectedCategoryId = newCatId;
    categoryName = newCatName;
    transaction['categoryId'] = newCatId;
    transaction['categoryName'] = newCatName;
    notifyListeners();
  }

  Future<int> addNewCategory(String name, int colorValue) async {
    int newId = await DatabaseHelper.instance.addCategory(
      name,
      color: colorValue,
    );
    await _loadData();
    return newId;
  }

  Future<void> updateGoal(
    int? newGoalId,
    String? newGoalName, {
    bool isGoalAddition = true,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      {'goalId': newGoalId, 'is_goal_addition': isGoalAddition ? 1 : 0},
      where: 'id = ?',
      whereArgs: [transaction['id']],
    );

    selectedGoalId = newGoalId;
    goalName = newGoalName;
    transaction['goalId'] = newGoalId;
    transaction['is_goal_addition'] = isGoalAddition ? 1 : 0;

    // Refresh goal name lookups if needed
    if (newGoalId != null && newGoalName == null) {
      await _loadData();
    } else {
      notifyListeners();
    }
  }

  Future<void> updateIsIgnored(bool val) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      {'isIgnored': val ? 1 : 0},
      where: 'id = ?',
      whereArgs: [transaction['id']],
    );
    isIgnored = val;
    transaction['isIgnored'] = val ? 1 : 0;
    notifyListeners();
  }

  Future<void> toggleIgnore() async {
    await updateIsIgnored(!isIgnored);
  }

  Future<void> updateIsLiquid(bool val) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      {'isLiquid': val ? 1 : 0},
      where: 'id = ?',
      whereArgs: [transaction['id']],
    );
    isLiquid = val;
    transaction['isLiquid'] = val ? 1 : 0;
    notifyListeners();
  }

  Future<bool> saveChanges(
    double newAmount,
    String? newNote, // This is now primarily the "Note" field
    int newDate,
    bool excludeFromBudget,
    bool isIgnored,
  ) async {
    try {
      final Map<String, dynamic> updateData = {
        'id': transaction['id'],
        'amount': newAmount,
        'date': newDate,
        'isExcluded': excludeFromBudget ? 1 : 0,
        'isIgnored': isIgnored ? 1 : 0,
        'categoryId': selectedCategoryId,
        'note': newNote, // Save the user's note here
      };

      // For manual transactions, we might still want to update 'sender' or 'body'
      // if the user edits them. But now we are shifting to using 'note'.
      // If the transaction is manual, let's say "Sender" is "Manual Entry" and we
      // don't change it. The "body" was used for description.
      // We should probably migrate legacy manual usage to 'note' too, but for now
      // let's just ensure 'note' is saved.

      await DatabaseHelper.instance.updateTransaction(updateData);

      // Update local state so UI reflects changes immediately
      transaction['amount'] = newAmount;
      transaction['date'] = newDate;
      transaction['isExcluded'] = excludeFromBudget ? 1 : 0;
      transaction['isIgnored'] = isIgnored ? 1 : 0;
      transaction['categoryId'] = selectedCategoryId;
      transaction['note'] = newNote; // Key fix!

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error saving transaction: $e");
      return false;
    }
  }

  Future<void> deleteTransaction() async {
    await DatabaseHelper.instance.deleteTransaction(transaction['id']);
  }
}
