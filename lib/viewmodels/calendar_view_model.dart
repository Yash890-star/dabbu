import 'package:flutter/material.dart';

import '../services/database_helper.dart';

enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc }

class CalendarViewModel extends ChangeNotifier {
  // --- State ---
  DateTime focusedDate = DateTime.now();
  DateTime? rangeStart; // Start of selection range
  DateTime? rangeEnd; // End of selection range

  // Data
  Map<int, double> dailyNet = {};
  Map<int, List<Map<String, dynamic>>> dailyTransactions = {};
  double maxNet = 1.0;

  // Filters/Sort
  SortOption sortOption = SortOption.dateDesc;
  final List<int> selectedCategoryIds = [];
  final List<String> selectedSenders = [];

  // Metadata
  List<Map<String, dynamic>> allCategories = [];
  Set<String> availableSenders = {};
  bool isLoading = true;

  // --- Initialization ---
  CalendarViewModel() {
    rangeStart = DateTime.now(); // Default to today
  }

  Future<void> init() async {
    await _fetchCategories();
    await fetchMonthData();
  }

  Future<void> _fetchCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    allCategories = cats;
    notifyListeners();
  }

  // --- Actions ---

  void changeMonth(int offset) {
    focusedDate = DateTime(focusedDate.year, focusedDate.month + offset, 1);

    // Reset Selection Logic
    final now = DateTime.now();
    if (focusedDate.year == now.year && focusedDate.month == now.month) {
      // Current Month -> Default to Today
      rangeStart = now;
    } else {
      // Other Month -> Default to 1st
      rangeStart = DateTime(focusedDate.year, focusedDate.month, 1);
    }
    rangeEnd = null; // Always reset range

    fetchMonthData(); // Will notify listeners
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> fetchMonthData() async {
    isLoading = true;
    notifyListeners();

    final start = DateTime(focusedDate.year, focusedDate.month, 1);
    final end = DateTime(
      focusedDate.year,
      focusedDate.month + 1,
      0,
      23,
      59,
      59,
    );

    final data = await DatabaseHelper.instance.getFilteredTransactions(
      startEpoch: start.millisecondsSinceEpoch,
      endEpoch: end.millisecondsSinceEpoch,
    );

    if (_isDisposed) return;

    // Process Data
    Map<int, double> tempNet = {};
    Map<int, List<Map<String, dynamic>>> tempTxs = {};
    double tempMax = 0;
    Set<String> senders = {};

    for (var tx in data) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      final day = date.day;
      final amount = (tx['amount'] as num).toDouble();
      final isDebit = tx['type'] == 'debit';

      // Collect Senders
      final name = tx['patternName'] ?? tx['sender'] ?? "Unknown";
      senders.add(name);

      // Aggregate Net
      double currentNet = tempNet[day] ?? 0.0;
      if (isDebit) {
        currentNet += amount;
      } else {
        currentNet -= amount;
      }
      tempNet[day] = currentNet;

      // Track Max
      if (currentNet.abs() > tempMax) {
        tempMax = currentNet.abs();
      }

      // Store Transaction
      if (tempTxs[day] == null) tempTxs[day] = [];
      tempTxs[day]!.add(tx);
    }

    dailyNet = tempNet;
    dailyTransactions = tempTxs;
    maxNet = tempMax == 0 ? 1.0 : tempMax;
    availableSenders = senders;
    isLoading = false;
    notifyListeners();
  }

  void onDaySelected(DateTime date) {
    if (rangeStart == null) {
      rangeStart = date;
      rangeEnd = null;
    } else if (rangeEnd == null) {
      if (date.isBefore(rangeStart!)) {
        rangeStart = date;
      } else if (isSameDay(date, rangeStart!)) {
        rangeEnd = null;
      } else {
        rangeEnd = date;
      }
    } else {
      rangeStart = date;
      rangeEnd = null;
    }
    notifyListeners();
  }

  void resetDate() {
    rangeStart = DateTime.now();
    rangeEnd = null;
    notifyListeners();
  }

  // --- Filtering & Sorting Actions ---

  void setSortOption(SortOption option) {
    sortOption = option;
    notifyListeners();
  }

  void toggleCategoryFilter(int categoryId) {
    if (selectedCategoryIds.contains(categoryId)) {
      selectedCategoryIds.remove(categoryId);
    } else {
      selectedCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  void toggleSenderFilter(String sender) {
    if (selectedSenders.contains(sender)) {
      selectedSenders.remove(sender);
    } else {
      selectedSenders.add(sender);
    }
    notifyListeners();
  }

  void resetFilters() {
    selectedCategoryIds.clear();
    selectedSenders.clear();
    sortOption = SortOption.dateDesc; // Reset sort

    // Reset Date Logic (Default to Today or 1st based on month, same as changeMonth)
    final now = DateTime.now();
    if (focusedDate.year == now.year && focusedDate.month == now.month) {
      rangeStart = now;
    } else {
      rangeStart = DateTime(focusedDate.year, focusedDate.month, 1);
    }
    rangeEnd = null;

    notifyListeners();
  }

  // --- Logic Helpers ---

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool isStart(DateTime date) {
    return rangeStart != null && isSameDay(date, rangeStart!);
  }

  bool isEnd(DateTime date) {
    return rangeEnd != null && isSameDay(date, rangeEnd!);
  }

  bool isInRange(DateTime date) {
    if (rangeStart == null || rangeEnd == null) return false;
    // Normalize
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(rangeStart!.year, rangeStart!.month, rangeStart!.day);
    final e = DateTime(rangeEnd!.year, rangeEnd!.month, rangeEnd!.day);
    return d.isAfter(s) && d.isBefore(e);
  }

  // --- Data Accessors ---

  List<Map<String, dynamic>> getTransactionsInRange() {
    List<Map<String, dynamic>> allTxs = [];
    if (rangeStart == null) {
      return [];
    }

    // 1. Gather
    if (rangeEnd == null) {
      if (dailyTransactions.containsKey(rangeStart!.day)) {
        allTxs.addAll(dailyTransactions[rangeStart!.day]!);
      }
    } else {
      DateTime current = DateTime(
        rangeStart!.year,
        rangeStart!.month,
        rangeStart!.day,
      );
      DateTime end = DateTime(rangeEnd!.year, rangeEnd!.month, rangeEnd!.day);

      if (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        while (!current.isAfter(end)) {
          if (current.month == focusedDate.month &&
              current.year == focusedDate.year) {
            final day = current.day;
            if (dailyTransactions.containsKey(day)) {
              allTxs.addAll(dailyTransactions[day]!);
            }
          }
          current = current.add(const Duration(days: 1));
        }
      }
    }

    // 2. Filter
    if (selectedCategoryIds.isNotEmpty || selectedSenders.isNotEmpty) {
      allTxs =
          allTxs.where((tx) {
            if (selectedCategoryIds.isNotEmpty) {
              if (!selectedCategoryIds.contains(tx['categoryId'])) return false;
            }
            if (selectedSenders.isNotEmpty) {
              final name = tx['patternName'] ?? tx['sender'] ?? "Unknown";
              if (!selectedSenders.contains(name)) return false;
            }
            return true;
          }).toList();
    }

    // 3. Sort
    allTxs.sort((a, b) {
      switch (sortOption) {
        case SortOption.dateDesc:
          return (b['date'] as int).compareTo(a['date'] as int);
        case SortOption.dateAsc:
          return (a['date'] as int).compareTo(b['date'] as int);
        case SortOption.amountDesc:
          return (b['amount'] as num).compareTo(a['amount'] as num);
        case SortOption.amountAsc:
          return (a['amount'] as num).compareTo(b['amount'] as num);
      }
    });

    return allTxs;
  }
}
