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
  Map<String, double> summaryData = {'expense': 0.0, 'income': 0.0};
  Map<DateTime, double> dailyTotals = {};
  double monthlyBudget = 0.0;
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

    notifyListeners();
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

  void changeSummaryMonth(int months) {
    final newDate = DateTime(summaryMonth.year, summaryMonth.month + months, 1);
    // Allow going back to any past month. Prevent going to FUTURE months beyond current.
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);

    if (newDate.isAfter(currentMonthStart)) return;

    summaryMonth = newDate;
    notifyListeners(); // Immediate update for UI
    refreshData();
  }

  bool get canGoNext {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(summaryMonth.year, summaryMonth.month + 1, 1);
    return !nextMonth.isAfter(currentMonthStart);
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
}
