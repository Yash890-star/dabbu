import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class GoalHistoryViewModel extends ChangeNotifier {
  Map<String, dynamic> goal = {};
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;

  // Initialize with the goal data passed from the UI
  void init(Map<String, dynamic> initialGoal) {
    goal = initialGoal;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    isLoading = true;
    notifyListeners();

    final data = await DatabaseHelper.instance.getFilteredTransactions(
      goalId: goal['id'],
    );

    transactions = data;
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadHistory();
  }

  Future<bool> toggleArchive() async {
    final isArchived = (goal['isArchived'] ?? 0) == 1;
    final newValue = !isArchived;

    await DatabaseHelper.instance.archiveGoal(goal['id'], newValue);

    // Update local state
    final updatedGoal = Map<String, dynamic>.from(goal);
    updatedGoal['isArchived'] = newValue ? 1 : 0;
    goal = updatedGoal;
    notifyListeners(); // Update UI (icon)

    return newValue;
  }

  Future<void> deleteGoal() async {
    await DatabaseHelper.instance.deleteGoal(goal['id']);
  }

  Future<void> linkTransactionToGoal(
    Map<String, dynamic> tx,
    bool isGoalAddition,
  ) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      {'goalId': goal['id'], 'is_goal_addition': isGoalAddition ? 1 : 0},
      where: 'id = ?',
      whereArgs: [tx['id']],
    );
    await _loadHistory();
  }

  Future<List<Map<String, dynamic>>> fetchUnlinkedTransactions() async {
    final fullList = await DatabaseHelper.instance.getTransactionsWithDetails(
      limit: 50,
    );
    return fullList.where((tx) => tx['goalId'] != goal['id']).toList();
  }

  // Helper for UI calculation
  double get totalSaved {
    double total = 0;
    for (var tx in transactions) {
      if ((tx['is_goal_addition'] ?? 1) == 1) {
        total += (tx['amount'] as num).toDouble();
      } else {
        total -= (tx['amount'] as num).toDouble();
      }
    }
    return total;
  }

  double get progress {
    final target = (goal['targetAmount'] as num).toDouble();
    return target > 0 ? (totalSaved / target).clamp(0.0, 1.0) : 0.0;
  }
}
