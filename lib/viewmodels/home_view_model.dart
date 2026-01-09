import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/message_helper.dart';

class HomeViewModel extends ChangeNotifier {
  // State
  String userName = "User";
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> goals = [];
  List<Map<String, dynamic>> upcomingBills = [];

  DateTime summaryMonth = DateTime.now();
  List<Map<String, dynamic>> checkpoints = [];
  Map<String, double> summaryData = {'expense': 0.0, 'income': 0.0};
  Map<DateTime, double> dailyTotals = {};
  double monthlyBudget = 0.0;

  // Tally Feature
  Map<String, dynamic>? lastCheckpoint;
  double currentLiquidBalance = 0.0;

  bool isSyncing = false;
  bool isLoading = true;

  Future<void> init() async {
    isLoading = true;
    notifyListeners(); // Notify start loading
    await DatabaseHelper.instance.seedDefaultCategories();
    await refreshData();
    isLoading = false;
    notifyListeners(); // Notify finished loading
  }

  Future<void> refreshData() async {
    final prefs = await SharedPreferences.getInstance();
    userName = prefs.getString('userName') ?? "User";

    // Fetch transactions for the selected summary month
    final start = DateTime(summaryMonth.year, summaryMonth.month, 1);
    final end = DateTime(
      summaryMonth.year,
      summaryMonth.month + 1,
      0,
      23,
      59,
      59,
      999,
    );

    final data = await DatabaseHelper.instance.getFilteredTransactions(
      startEpoch: start.millisecondsSinceEpoch,
      endEpoch: end.millisecondsSinceEpoch,
    );
    final cats = await DatabaseHelper.instance.getCategories();
    final allGoals = await DatabaseHelper.instance.getAllGoals();
    final subs = await DatabaseHelper.instance.getAllSubscriptions();

    // Fetch Monthly Summary
    final summary = await DatabaseHelper.instance.getMonthlySummary(
      summaryMonth.month,
      summaryMonth.year,
    );

    // Filter upcoming bills (Next 7 days)
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    final upcoming =
        subs.where((s) {
          if ((s['isActive'] ?? 0) == 0) return false;
          final date = DateTime.fromMillisecondsSinceEpoch(s['nextBillDate']);
          // Show if overdue or within next week
          return date.isBefore(nextWeek);
        }).toList();

    upcoming.sort(
      (a, b) => (a['nextBillDate'] as int).compareTo(b['nextBillDate'] as int),
    );

    // Fetch Budget Overrides for the selected month
    final budgetOverrides = await DatabaseHelper.instance.getMonthBudgets(
      summaryMonth.month,
      summaryMonth.year,
    );

    // 1. Determine Total Monthly Budget (Override > Default)
    double finalBudget =
        budgetOverrides['total'] ?? (prefs.getDouble('monthly_budget') ?? 0.0);

    // 2. Apply Category Limit Overrides
    final updatedCats =
        cats.map((cat) {
          final catId = cat['id'];
          final override = budgetOverrides['cat_$catId'];
          if (override != null) {
            final newCat = Map<String, dynamic>.from(cat);
            newCat['budgetLimit'] = override;
            return newCat;
          }
          return cat;
        }).toList();

    // Calculate totals
    final totals = _calculateDailyTotals(data);

    transactions = data;
    categories = updatedCats;
    goals = allGoals;
    upcomingBills = upcoming;
    dailyTotals = totals;
    monthlyBudget = finalBudget;
    summaryData = summary;

    // Calculate Tally Balance
    await _calculateLiquidBalance();

    notifyListeners();
  }

  Future<void> _calculateLiquidBalance() async {
    final checkpoint = await DatabaseHelper.instance.getLastCheckpoint();
    final startEpoch =
        (checkpoint?['date'] as int?) ?? 0; // 0 = Beginning of time

    final db = await DatabaseHelper.instance.database;

    // Sum Liquid Income
    final incomeRes = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions 
      WHERE date > ? AND isLiquid = 1 AND (isIgnored IS NULL OR isIgnored = 0) 
      AND type IN ('credit', 'income')
    ''',
      [startEpoch],
    );

    // Sum Liquid Expense
    final expenseRes = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions 
      WHERE date > ? AND isLiquid = 1 AND (isIgnored IS NULL OR isIgnored = 0) 
      AND type IN ('debit', 'expense')
    ''',
      [startEpoch],
    );

    final income = (incomeRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final expense = (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final baseBalance = (checkpoint?['balance'] as num?)?.toDouble() ?? 0.0;

    lastCheckpoint = checkpoint;
    checkpoints = await DatabaseHelper.instance.getCheckpoints();
    currentLiquidBalance = baseBalance + income - expense;
  }

  // Helper to sum amounts per day and per category
  Map<DateTime, double> _calculateDailyTotals(List<Map<String, dynamic>> txs) {
    Map<DateTime, double> totals = {};
    _categorySpending = {}; // Reset category spending

    for (var tx in txs) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      final key = DateTime(
        date.year,
        date.month,
        date.day,
      ); // Normalize to midnight

      final amount = (tx['amount'] as num).toDouble();
      final isIgnored = (tx['isIgnored'] as int? ?? 0) == 1;

      if (isIgnored) continue; // Skip calculations

      // Daily Totals
      if (!totals.containsKey(key)) {
        totals[key] = 0.0;
      }
      totals[key] = totals[key]! + amount;

      // Category Totals
      // Check if it's an expense (DEBIT) before adding to category spending
      final type = (tx['type'] as String?)?.toUpperCase() ?? '';
      if (type.contains('DEBIT')) {
        final catId =
            tx['categoryId'] as int? ?? 0; // Default to 0 (Uncategorized)
        _categorySpending[catId] = (_categorySpending[catId] ?? 0.0) + amount;
      }
    }
    return totals;
  }

  // Exposed getter for category spending
  Map<int, double> _categorySpending = {};
  Map<int, double> get categorySpending => _categorySpending;

  Future<void> changeSummaryMonth(int months) async {
    final newDate = DateTime(summaryMonth.year, summaryMonth.month + months, 1);

    // Check if new month is in the future
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);

    // General Restriction: Allow navigation only if:
    // 1. It is the Current Month (Always allow accessibility to "Now")
    // 2. OR The target month has transactions.

    // Note: We use isAtSameMomentAs for precise month comparison
    final isCurrentMonth =
        newDate.year == currentMonthStart.year &&
        newDate.month == currentMonthStart.month;

    if (!isCurrentMonth) {
      final hasData = await DatabaseHelper.instance.hasTransactionsInMonth(
        newDate.month,
        newDate.year,
      );
      if (!hasData) return;
    }

    summaryMonth = newDate;
    notifyListeners(); // Immediate update for UI
    await refreshData();
  }

  bool get canGoNext {
    return true; // Always allow next
  }

  void resetSummaryMonth() {
    summaryMonth = DateTime.now();
    notifyListeners();
    refreshData();
  }

  Future<int> syncMessages() async {
    isSyncing = true;
    notifyListeners();

    final helper = MessageHelper();
    int newCount = await helper.processNewMessages(lookBackDays: 60);
    await refreshData();

    isSyncing = false;
    notifyListeners();
    return newCount;
  }

  Future<void> createGoal(
    String name,
    double targetAmount,
    int colorValue,
  ) async {
    await DatabaseHelper.instance.createGoal({
      'name': name,
      'targetAmount': targetAmount,
      'color': colorValue,
      'icon': 'savings',
    });
    await refreshData();
  }

  Future<void> saveBudgetSettings(
    double totalBudget,
    Map<int, double> categoryBudgets,
  ) async {
    // Save Total
    await DatabaseHelper.instance.setMonthBudget(
      month: summaryMonth.month,
      year: summaryMonth.year,
      amount: totalBudget,
      categoryId: 0,
    );

    // Save Categories
    for (var entry in categoryBudgets.entries) {
      await DatabaseHelper.instance.setMonthBudget(
        month: summaryMonth.month,
        year: summaryMonth.year,
        amount: entry.value,
        categoryId: entry.key,
      );
    }

    await refreshData();
  }

  Future<double> addCheckpoint(
    double actualBalance,
    String note, {
    DateTime? date,
  }) async {
    final checkpointDate = date ?? DateTime.now();
    // Re-verify calculated balance at that specific moment for accurate diff
    // The UI might have shown an estimated one, but let's be precise if we can.
    // If date is now, use currentLiquidBalance. If past, use getLiquidBalanceAt.

    double calculatedAtTime;
    if (date == null || date.difference(DateTime.now()).inMinutes.abs() < 5) {
      calculatedAtTime = currentLiquidBalance;
    } else {
      calculatedAtTime = await getLiquidBalanceAt(date);
    }

    final diff = actualBalance - calculatedAtTime;

    await DatabaseHelper.instance.addCheckpoint({
      'date': checkpointDate.millisecondsSinceEpoch,
      'balance': actualBalance,
      'calculatedBalance': calculatedAtTime,
      'diff': diff,
      'note': note,
    });

    await refreshData();
    return diff;
  }

  Future<void> addAdjustmentTransaction(double amount, DateTime date) async {
    // If amount is negative (Leak): We need to ADD an expense of ABS(amount).
    // If amount is positive (Found): We need to ADD an income of amount.

    final isExpense = amount < 0;
    final absAmount = amount.abs();

    await DatabaseHelper.instance.insertTransaction({
      'amount': absAmount,
      'type': isExpense ? 'debit' : 'credit',
      'date': date.millisecondsSinceEpoch,
      'sender': 'System Adjustment',
      'body':
          isExpense
              ? 'Balance Correction (Leak)'
              : 'Balance Correction (Found)',
      'categoryId':
          0, // Uncategorized or specific 'Adjustment' category? For now 0.
      'isLiquid': 1,
      'isIgnored': 0,
    });

    await refreshData();
  }

  Future<double> getLiquidBalanceAt(DateTime date) async {
    final targetEpoch = date.millisecondsSinceEpoch;
    final checkpoint = await DatabaseHelper.instance.getLastCheckpointBefore(
      targetEpoch,
    );
    final startEpoch = (checkpoint?['date'] as int?) ?? 0;

    final db = await DatabaseHelper.instance.database;

    // Sum Liquid Income
    final incomeRes = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions 
      WHERE date > ? AND date <= ? AND isLiquid = 1 AND (isIgnored IS NULL OR isIgnored = 0) 
      AND type IN ('credit', 'income')
    ''',
      [startEpoch, targetEpoch],
    );

    // Sum Liquid Expense
    final expenseRes = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM transactions 
      WHERE date > ? AND date <= ? AND isLiquid = 1 AND (isIgnored IS NULL OR isIgnored = 0) 
      AND type IN ('debit', 'expense')
    ''',
      [startEpoch, targetEpoch],
    );

    final income = (incomeRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final expense = (expenseRes.first['total'] as num?)?.toDouble() ?? 0.0;
    final baseBalance = (checkpoint?['balance'] as num?)?.toDouble() ?? 0.0;

    return baseBalance + income - expense;
  }
}
