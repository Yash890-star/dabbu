import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_telephony/telephony.dart';
import '../services/database_helper.dart';

class SettingsViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> patterns = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> goals = [];
  double monthlyBudget = 0.0;
  bool isLoading = false;

  final List<Color> categoryColors = AppColors.categoryColors;

  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();

    final db = DatabaseHelper.instance;
    final pats = await db.database.then((d) => d.query('patterns'));
    final cats = await db.getCategories();
    final goalsList = await db.getAllGoals();
    final prefs = await SharedPreferences.getInstance();
    final budget = prefs.getDouble('monthly_budget') ?? 0.0;

    patterns = pats;
    categories = cats;
    goals = goalsList;
    monthlyBudget = budget;

    isLoading = false;
    notifyListeners();
  }

  Future<void> setMonthlyBudget(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthly_budget', amount);
    await loadData();
  }

  // Returns true if global budget was updated
  Future<bool> addOrUpdateCategory({
    int? id,
    required String name,
    required int colorValue,
    required double budgetLimit,
    String? icon,
  }) async {
    bool budgetUpdated = false;

    if (id == null) {
      await DatabaseHelper.instance.addCategory(
        name,
        color: colorValue,
        budget: budgetLimit,
      );
    } else {
      await DatabaseHelper.instance.updateCategory({
        'id': id,
        'name': name,
        'color': colorValue,
        'budgetLimit': budgetLimit,
        'icon': icon,
      });
    }

    // Auto-update Monthly Budget logic
    if (budgetLimit > 0) {
      double totalCategoryBudget = 0.0;
      final allCats = await DatabaseHelper.instance.getCategories();
      for (var c in allCats) {
        // If we just updated 'c', its new value is in allCats?
        // Yes, getCategories queries the DB, so it should be fresh.
        totalCategoryBudget += (c['budgetLimit'] as num? ?? 0.0).toDouble();
      }

      if (totalCategoryBudget > monthlyBudget) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('monthly_budget', totalCategoryBudget);
        budgetUpdated = true;
      }
    }
    await loadData();
    return budgetUpdated;
  }

  Future<void> deleteCategory(int id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    await loadData();
  }

  Future<void> deletePattern(int id, {required bool deleteTransactions}) async {
    await DatabaseHelper.instance.deletePattern(
      id,
      deleteTransactions: deleteTransactions,
    );
    await loadData();
  }

  Future<void> updatePattern(int id, String name, bool isLiquid) async {
    await DatabaseHelper.instance.updatePattern({
      'id': id,
      'name': name,
      'isLiquid': isLiquid ? 1 : 0,
    });

    // Also update all existing transactions for this pattern
    await DatabaseHelper.instance.database.then((db) async {
      await db.update(
        'transactions',
        {'isLiquid': isLiquid ? 1 : 0},
        where: 'patternId = ?',
        whereArgs: [id],
      );
    });

    await loadData();
  }

  Future<void> restoreGoal(int id) async {
    await DatabaseHelper.instance.archiveGoal(id, false);
    await loadData();
  }

  Future<SmsMessage?> findLatestSms(String senderId) async {
    final Telephony telephony = Telephony.instance;
    try {
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS).like("%$senderId%"),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      if (messages.isNotEmpty) {
        return messages.first;
      }
    } catch (e) {
      debugPrint("Error finding SMS: $e");
    }
    return null;
  }

  // --- Category Rules ---
  Future<List<Map<String, dynamic>>> getCategoryRules(int categoryId) async {
    return await DatabaseHelper.instance.getCategoryRules(categoryId);
  }

  Future<void> deleteCategoryRule(int ruleId) async {
    await DatabaseHelper.instance.deleteCategoryRule(ruleId);
    notifyListeners(); // Refresh UI if showing list
  }
}
