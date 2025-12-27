import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../utils/cms.dart';

class CategorySummary {
  final String name;
  final double amount;
  final Color color;
  final double percentage;

  CategorySummary({
    required this.name,
    required this.amount,
    required this.color,
    required this.percentage,
  });
}

class InsightItem {
  final String categoryName;
  final double currentAmount;
  final double prevAmount;
  final double percentageChange;
  final double diffAmount;

  InsightItem({
    required this.categoryName,
    required this.currentAmount,
    required this.prevAmount,
    required this.percentageChange,
    required this.diffAmount,
  });
}

class AnalyticsViewModel extends ChangeNotifier {
  // --- Filter State ---
  String timeFrame = 'Month';
  DateTime focusedDate = DateTime.now();
  List<int> selectedCategoryIds = [];
  List<int> selectedPatternIds = [];
  String transactionType = 'debit'; // 'debit' or 'credit'

  // --- Data State ---
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> allCategories = [];
  List<Map<String, dynamic>> allPatterns = [];

  List<CategorySummary> categorySummaries = [];
  List<InsightItem> insights = [];

  bool isLoading = true;

  // --- Initialization ---
  Future<void> init() async {
    await _loadFilters();
    await _fetchData();
  }

  Future<void> refreshAll() async {
    await _loadFilters();
    await _fetchData();
  }

  Future<void> _loadFilters() async {
    final db = DatabaseHelper.instance;
    final cats = await db.getCategories();
    final pats = await db.database.then((d) => d.query('patterns'));

    // Create a mutable copy of patterns and add the "Manual" option
    // using ID -1 as a sentinel value.
    final List<Map<String, dynamic>> modifiablePatterns = List.from(pats);
    modifiablePatterns.add({
      'id': -1,
      'name': CMS.analytics['manual_transactions'],
      'senderId': 'MANUAL',
      'patternRegex': '',
      'messageType': 'debit',
    });

    allCategories = cats;
    allPatterns = modifiablePatterns;
    notifyListeners();
  }

  // --- Actions ---

  void setTimeFrame(String frame) {
    if (timeFrame == frame) return;
    timeFrame = frame;
    // Reset date to now or similar logic if needed?
    // Usually standard to keep focusedDate but logically aligned.
    // The previous code kept focusedDate and just adjusted range logic.
    _fetchData();
  }

  void changeDate(int offset) {
    if (timeFrame == 'Day') {
      focusedDate = focusedDate.add(Duration(days: offset));
    } else if (timeFrame == 'Week') {
      focusedDate = focusedDate.add(Duration(days: offset * 7));
    } else {
      focusedDate = DateTime(focusedDate.year, focusedDate.month + offset, 1);
    }
    _fetchData();
  }

  void setTransactionType(String type) {
    if (transactionType == type) return;
    transactionType = type;
    _fetchData();
  }

  void updateCategoryFilter(List<int> ids) {
    selectedCategoryIds = ids;
    _fetchData();
  }

  void updatePatternFilter(List<int> ids) {
    selectedPatternIds = ids;
    _fetchData();
  }

  // --- Getters for UI ---

  String getDateLabel() {
    if (timeFrame == 'Day') return DateFormat.yMMMd().format(focusedDate);
    if (timeFrame == 'Week') {
      final start = focusedDate.subtract(
        Duration(days: focusedDate.weekday - 1),
      );
      final end = start.add(const Duration(days: 6));
      return "${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}";
    }
    return DateFormat.yMMMM().format(focusedDate);
  }

  // --- Logic helpers ---

  (int, int) _getDateRange() {
    DateTime start, end;
    final date = DateTime(focusedDate.year, focusedDate.month, focusedDate.day);

    if (timeFrame == 'Day') {
      start = date;
      end = date.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else if (timeFrame == 'Week') {
      start = date.subtract(Duration(days: date.weekday - 1));
      end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else {
      start = DateTime(date.year, date.month, 1);
      end = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
    }
    return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }

  (int, int) _getPreviousDateRange() {
    DateTime start, end;
    final date = DateTime(focusedDate.year, focusedDate.month, focusedDate.day);

    if (timeFrame == 'Day') {
      final prevDate = date.subtract(const Duration(days: 1));
      start = prevDate;
      end = prevDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else if (timeFrame == 'Week') {
      final startCurrent = date.subtract(Duration(days: date.weekday - 1));
      start = startCurrent.subtract(const Duration(days: 7));
      end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else {
      start = DateTime(date.year, date.month - 1, 1);
      end = DateTime(date.year, date.month, 0, 23, 59, 59);
    }
    return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }

  Future<void> _fetchData() async {
    isLoading = true;
    notifyListeners();

    final (start, end) = _getDateRange();
    final (startPrev, endPrev) = _getPreviousDateRange();
    final db = DatabaseHelper.instance;

    // 1. Current Period Data
    final data = await db.getFilteredTransactions(
      startEpoch: start,
      endEpoch: end,
      categoryIds: selectedCategoryIds,
      patternIds: selectedPatternIds,
      type: transactionType,
    );

    // 2. Previous Period Data (For Insights)
    final prevData = await db.getFilteredTransactions(
      startEpoch: startPrev,
      endEpoch: endPrev,
      categoryIds: selectedCategoryIds,
      patternIds: selectedPatternIds,
      type: transactionType,
    );

    // --- Calculate Summaries & Insights ---
    Map<String, double> totals = {};
    Map<String, Color> colors = {};
    double totalFilterAmount = 0;

    for (var tx in data) {
      final catName = tx['categoryName'] ?? 'Uncategorized';
      final amount = (tx['amount'] as num).toDouble();
      totalFilterAmount += amount;
      totals[catName] = (totals[catName] ?? 0) + amount;

      if (!colors.containsKey(catName)) {
        int? colorInt = tx['categoryColor'];
        colors[catName] = colorInt != null ? Color(colorInt) : Colors.grey;
      }
    }

    Map<String, double> prevTotals = {};
    for (var tx in prevData) {
      final catName = tx['categoryName'] ?? 'Uncategorized';
      final amount = (tx['amount'] as num).toDouble();
      prevTotals[catName] = (prevTotals[catName] ?? 0) + amount;
    }

    List<InsightItem> calculatedInsights = [];
    totals.forEach((catName, currentAmount) {
      final prevAmount = prevTotals[catName] ?? 0.0;
      if (prevAmount > 0) {
        final diff = currentAmount - prevAmount;
        final pctChange = (diff / prevAmount) * 100;
        if (pctChange.abs() >= 5 || diff.abs() >= 50) {
          calculatedInsights.add(
            InsightItem(
              categoryName: catName,
              currentAmount: currentAmount,
              prevAmount: prevAmount,
              percentageChange: pctChange,
              diffAmount: diff,
            ),
          );
        }
      } else if (currentAmount > 0 && prevAmount == 0) {
        calculatedInsights.add(
          InsightItem(
            categoryName: catName,
            currentAmount: currentAmount,
            prevAmount: 0,
            percentageChange: 100,
            diffAmount: currentAmount,
          ),
        );
      }
    });

    prevTotals.forEach((catName, prevAmount) {
      if (!totals.containsKey(catName) && prevAmount > 0) {
        calculatedInsights.add(
          InsightItem(
            categoryName: catName,
            currentAmount: 0,
            prevAmount: prevAmount,
            percentageChange: -100,
            diffAmount: -prevAmount,
          ),
        );
      }
    });

    calculatedInsights.sort(
      (a, b) => b.diffAmount.abs().compareTo(a.diffAmount.abs()),
    );

    List<CategorySummary> summaries =
        totals.entries.map((e) {
          return CategorySummary(
            name: e.key,
            amount: e.value,
            color: colors[e.key] ?? Colors.grey,
            percentage:
                totalFilterAmount == 0
                    ? 0
                    : (e.value / totalFilterAmount) * 100,
          );
        }).toList();

    summaries.sort((a, b) => b.amount.compareTo(a.amount));

    transactions = data;
    categorySummaries = summaries;
    insights = calculatedInsights;
    isLoading = false;
    notifyListeners();
  }
}
