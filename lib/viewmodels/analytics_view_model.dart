import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../utils/app_colors.dart';
import '../utils/cms.dart';

enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc }

class CategorySummary {
  final int id;
  final String name;
  final double amount;
  final Color color;
  final double percentage;

  CategorySummary({
    required this.id,
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
  String timeFrame = 'Month'; // Presets: Month, Week, Day, Custom
  DateTime focusedDate = DateTime.now(); // Controls the Heatmap Month

  // Selection Range (within the focused month)
  DateTime? rangeStart;
  DateTime? rangeEnd;

  List<int> selectedCategoryIds = [];
  List<String> selectedNames =
      []; // Changed from attributes: Sender ID -> Name (Pattern/Sender)
  List<int> selectedPatternIds = [];
  String transactionType = 'all'; // 'all', 'debit', 'credit'
  SortOption sortOption = SortOption.dateDesc;

  // Computed Stats for Summary Block
  int filteredCount = 0;
  double filteredTotalCredit = 0.0;
  double filteredTotalDebit = 0.0;

  // --- Data State ---

  // 1. Heatmap Data (Full Month)
  Map<int, double> dailyNet = {};
  Map<int, List<Map<String, dynamic>>> dailyTransactions = {};
  double maxNet = 1.0;

  // 2. Selected Range Data (For Charts/List)
  List<Map<String, dynamic>> transactions = [];
  List<CategorySummary> categorySummaries = [];
  List<InsightItem> insights = [];

  // Metadata
  List<Map<String, dynamic>> allCategories = [];
  List<Map<String, dynamic>> allPatterns = [];
  List<String> availableNames = []; // Changed from availableSenders

  bool isLoading = true;
  bool isPieChartExpanded = false;

  // --- Initialization ---
  AnalyticsViewModel() {
    _initRangeDefault();
  }

  Future<void> init() async {
    await _loadFilters();
    await _fetchData();
  }

  Future<void> refreshAll() async {
    await _loadFilters();
    await _fetchData();
  }

  void _initRangeDefault() {
    final now = DateTime.now();
    focusedDate = now;
    // Default: Full Month
    timeFrame = 'Month';
    rangeStart = DateTime(now.year, now.month, 1);
    rangeEnd = DateTime(now.year, now.month + 1, 0);
  }

  Future<void> _loadFilters() async {
    final db = DatabaseHelper.instance;
    final cats = await db.getCategories();
    final pats = await db.database.then((d) => d.query('patterns'));

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
    if (!_isDisposed) notifyListeners();
  }

  // --- Actions ---

  void setTimeFrame(String frame) {
    if (timeFrame == frame) return;
    timeFrame = frame;

    final now = DateTime.now();
    // Logic to set range based on frame relative to focusedDate
    if (frame == 'Month') {
      rangeStart = DateTime(focusedDate.year, focusedDate.month, 1);
      rangeEnd = DateTime(focusedDate.year, focusedDate.month + 1, 0);
    } else if (frame == 'Week') {
      // Find week containing focusedDate (or today if match)
      DateTime target =
          (focusedDate.year == now.year && focusedDate.month == now.month)
              ? now
              : DateTime(focusedDate.year, focusedDate.month, 1);
      rangeStart = target.subtract(Duration(days: target.weekday - 1));
      rangeEnd = rangeStart!.add(const Duration(days: 6));
    } else if (frame == 'Day') {
      rangeStart =
          (focusedDate.year == now.year && focusedDate.month == now.month)
              ? now
              : DateTime(focusedDate.year, focusedDate.month, 1);
      rangeEnd = null;
    }

    _processRangeData(); // Re-calc stats without re-fetching full month if possible?
    // Actually, changing frame might just update range. Heatmap is month-bound.
    notifyListeners();
  }

  void togglePieChart() {
    isPieChartExpanded = !isPieChartExpanded;
    notifyListeners();
  }

  void changeDate(int offset) {
    // Moves the Focused Month
    focusedDate = DateTime(focusedDate.year, focusedDate.month + offset, 1);

    // Reset Range to Full Month (Default behavior request)
    rangeStart = DateTime(focusedDate.year, focusedDate.month, 1);
    rangeEnd = DateTime(focusedDate.year, focusedDate.month + 1, 0);
    timeFrame = 'Month'; // Set to Month to reflect full selection

    _fetchData();
  }

  void onDaySelected(DateTime date) {
    // Interaction with Heatmap updates the Custom Range
    // timeFrame = 'Custom'; // Custom range logic

    if (rangeStart == null) {
      rangeStart = date;
      rangeEnd = null;
    } else if (rangeEnd == null) {
      if (date.isBefore(rangeStart!)) {
        rangeStart = date;
      } else if (_isSameDay(date, rangeStart!)) {
        rangeEnd = null;
      } else {
        rangeEnd = date;
      }
    } else {
      rangeStart = date;
      rangeEnd = null;
    }

    _processRangeData();
    notifyListeners();
  }

  void setTransactionType(String type) {
    if (transactionType == type) return;
    transactionType = type;
    _fetchData();
  }

  void selectFullMonth() {
    rangeStart = DateTime(focusedDate.year, focusedDate.month, 1);
    rangeEnd = DateTime(focusedDate.year, focusedDate.month + 1, 0);
    timeFrame = 'Month';
    _processRangeData();
    notifyListeners();
  }

  void toggleCategoryFilter(int categoryId) {
    if (selectedCategoryIds.contains(categoryId)) {
      selectedCategoryIds.remove(categoryId);
    } else {
      selectedCategoryIds.add(categoryId);
    }
    _processRangeData();
    notifyListeners();
  }

  void resetCategoryFilters() {
    selectedCategoryIds.clear();
    _processRangeData();
    notifyListeners();
  }

  void updateCategoryFilter(List<int> ids) {
    selectedCategoryIds = ids;
    _processRangeData();
    notifyListeners();
  }

  void toggleNameFilter(String name) {
    if (selectedNames.contains(name)) {
      selectedNames.remove(name);
    } else {
      selectedNames.add(name);
    }
    _processRangeData();
    notifyListeners();
  }

  void resetAllFilters() {
    selectedCategoryIds.clear();
    selectedNames.clear();
    transactionType = 'all';
    sortOption = SortOption.dateDesc;

    // We also need to reset the date if 'Master Reset' implies everything?
    // Usually 'Filters' implies the non-date stuff, but let's stick to filters within the view.
    // The user requirement says "reset all the filters and sort options".
    // It doesn't explicitly say "reset date", so we keep the date range as is.

    _processRangeData();
    // We might need to re-fetch if transactionType changed and we were relying on it for fetch (which we decided we aren't, mostly)
    // But _fetchData does use transactionType for Heatmap generation.
    _fetchData();
  }

  void setSortOption(SortOption option) {
    sortOption = option;
    _sortTransactions();
    notifyListeners();
  }

  // --- Getters for UI ---

  String getDateLabel() {
    if (rangeStart == null) return "Select Date";
    if (rangeEnd == null) return DateFormat.yMMMd().format(rangeStart!);
    return "${DateFormat.MMMd().format(rangeStart!)} - ${DateFormat.MMMd().format(rangeEnd!)}";
  }

  List<Map<String, dynamic>> getTransactionsInRange() => transactions;

  // --- Logic helpers ---

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool isStart(DateTime date) {
    return rangeStart != null && _isSameDay(date, rangeStart!);
  }

  bool isEnd(DateTime date) {
    return rangeEnd != null && _isSameDay(date, rangeEnd!);
  }

  bool isInRange(DateTime date) {
    if (rangeStart == null || rangeEnd == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(rangeStart!.year, rangeStart!.month, rangeStart!.day);
    final e = DateTime(rangeEnd!.year, rangeEnd!.month, rangeEnd!.day);
    return d.isAfter(s) && d.isBefore(e);
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _fetchData() async {
    isLoading = true;
    notifyListeners();

    // 1. Fetch Month Data for Heatmap (Ignoring type filter for Heatmap mostly? Or apply it?
    // Usually Heatmap shows net intensity regardless of filter, or reflects filter.
    // Let's assume Heatmap reflects the filter context if possible, but Heatmap often needs both Income/Expense to show Net.
    // However, the user asked for income/expense filter. If Expense is selected, Heatmap should probably just show expense intensity.
    // CURRENT LOGIC: _fetchMonthData fetches ALL types, then calculates dailyNet.
    // If I filter by 'debit' only, dailyNet should reflect that?
    // Let's stick to: Heatmap shows ALL provided by DB, but we can filter the aggregation.

    // Fetch FULL MONTH data for the Heatmap base
    final startMonth = DateTime(focusedDate.year, focusedDate.month, 1);
    final endMonth = DateTime(
      focusedDate.year,
      focusedDate.month + 1,
      0,
      23,
      59,
      59,
    );

    final data = await DatabaseHelper.instance.getFilteredTransactions(
      startEpoch: startMonth.millisecondsSinceEpoch,
      endEpoch: endMonth.millisecondsSinceEpoch,
      // We do NOT filter category/type here for the raw data, we filter in memory
      // because changing a filter shouldn't require re-fetching DB if we just hide items.
      // But for performance, maybe we filter by Pattern/Category in UI?
      // Actually, let's fetch EVERYTHING for the month and filter in memory. Dates are small enough.
    );

    if (_isDisposed) return;

    // Populate Heatmap & Daily Map
    Map<int, double> tempNet = {};
    Map<int, List<Map<String, dynamic>>> tempTxs = {};
    double tempMax = 0;

    for (var tx in data) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      final day = date.day;
      final amount = (tx['amount'] as num).toDouble();
      final isDebit = tx['type'] == 'debit';

      // Apply TYPE Filter to Heatmap?
      // If user selected "Expense", should heatmap show Income days?
      // User request: "along with the expense and income filter".
      // Let's assume this filter applies to EVERYTHING including heatmap.
      // Apply TYPE Filter to Heatmap
      if (transactionType != 'all') {
        if (transactionType == 'debit' && !isDebit) continue;
        if (transactionType == 'credit' && isDebit) continue;
      }

      double currentNet = tempNet[day] ?? 0.0;
      if (isDebit) {
        currentNet += amount;
      } else {
        currentNet -= amount;
      }

      tempNet[day] = currentNet;
      if (currentNet.abs() > tempMax) tempMax = currentNet.abs();

      if (tempTxs[day] == null) tempTxs[day] = [];
      tempTxs[day]!.add(tx);
    }

    dailyNet = tempNet;
    dailyTransactions = tempTxs;
    maxNet = tempMax == 0 ? 1.0 : tempMax;

    _processRangeData(); // This will populate proper transactions/insights list

    isLoading = false;
    notifyListeners();
  }

  void _processRangeData() {
    // Gather transactions from dailyTransactions based on Range
    List<Map<String, dynamic>> rangeTxs = [];

    if (rangeStart != null) {
      DateTime current = DateTime(
        rangeStart!.year,
        rangeStart!.month,
        rangeStart!.day,
      );
      DateTime end =
          (rangeEnd != null)
              ? DateTime(rangeEnd!.year, rangeEnd!.month, rangeEnd!.day)
              : current;

      while (!current.isAfter(end)) {
        if (current.month == focusedDate.month) {
          final dayTxs = dailyTransactions[current.day];
          if (dayTxs != null) {
            rangeTxs.addAll(dayTxs);
          }
        }
        current = current.add(const Duration(days: 1));
      }
    }

    // Separate unfiltered Transactions for stats calculation
    List<Map<String, dynamic>> unfilteredRangeTxs = List.from(rangeTxs);

    // Filter by Category/Patterns/Names for the Transaction List & Heatmap
    if (selectedCategoryIds.isNotEmpty ||
        selectedPatternIds.isNotEmpty ||
        selectedNames.isNotEmpty) {
      rangeTxs =
          rangeTxs.where((tx) {
            if (selectedCategoryIds.isNotEmpty &&
                !selectedCategoryIds.contains(tx['categoryId'])) {
              return false;
            }

            if (selectedNames.isNotEmpty) {
              // Prefer Pattern Name, fallback to Sender
              final name = tx['patternName'] ?? tx['sender'] ?? '';
              if (!selectedNames.contains(name)) return false;
            }

            return true;
          }).toList();
    }

    transactions = rangeTxs;
    _sortTransactions();

    // Extract available names from UNFILTERED range txs
    final uniqueNames =
        unfilteredRangeTxs
            .map((e) => (e['patternName'] ?? e['sender']) as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
    uniqueNames.sort();
    availableNames = uniqueNames;

    _calculateStats(
      unfilteredRangeTxs,
    ); // Pass unfiltered txs for Category List Stats (usually Category breakdown shows overall usage?)
    // modifying this: Usually Category Bento shows breakdown of CURRENT view?
    // If I filter by "Amazon", I expect the Category Bento to show "Shopping: $X" (where X is Amazon only).
    // BUT, the existing logic passes `unfilteredRangeTxs`.
    // If I change this, I change existing behavior.
    // User asked for "filters allowing the users to filter the data... these will affect the transactions as well".
    // And "CategoryBento... implementation... these will affect the transactions".
    // It seems the Category Bento is a FILTER controller, so it should probably show UNFILTERED data (or else if I select "Shopping", "Food" disappears?).
    // Yes, usually filter lists show all options. So passing `unfilteredRangeTxs` to calculate Category Summaries is correct for the FILTER UI.

    // However, we need to calculate the NEW Summary Row (Count, Credit, Debit) based on likely the FILTERED transactions.
    _calculateFilteredSummary();
  }

  void _sortTransactions() {
    transactions.sort((a, b) {
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
  }

  void _calculateStats(List<Map<String, dynamic>> sourceTxs) {
    // Calculate Pie Chart (Category Summaries) & Insights for the Transactions List
    Map<String, double> totals = {};
    Map<String, int> catIds = {}; // Map name to ID
    Map<String, Color> colors = {};
    double totalAmount = 0;

    for (var tx in sourceTxs) {
      final amount = (tx['amount'] as num).toDouble();
      totalAmount += amount;

      final catName = tx['categoryName'] ?? 'Uncategorized';
      final catId = tx['categoryId'] as int?; // might be null

      totals[catName] = (totals[catName] ?? 0) + amount;
      if (catId != null) catIds[catName] = catId;

      if (!colors.containsKey(catName)) {
        int? colorInt = tx['categoryColor'];
        colors[catName] =
            colorInt != null ? Color(colorInt) : AppColors.defaultCategoryColor;
      }
    }

    categorySummaries =
        totals.entries.map((e) {
          return CategorySummary(
            id: catIds[e.key] ?? -1,
            name: e.key,
            amount: e.value,
            color: colors[e.key] ?? Colors.grey,
            percentage: totalAmount == 0 ? 0 : (e.value / totalAmount) * 100,
          );
        }).toList();

    // Sort: Selected first, then Amount desc
    categorySummaries.sort((a, b) {
      final isSelectedA = selectedCategoryIds.contains(a.id);
      final isSelectedB = selectedCategoryIds.contains(b.id);

      if (isSelectedA && !isSelectedB) return -1;
      if (!isSelectedA && isSelectedB) return 1;

      return b.amount.compareTo(a.amount);
    });

    insights.clear(); // Insights simplified/cleared for now
  }

  void _calculateFilteredSummary() {
    filteredCount = transactions.length;
    filteredTotalCredit = 0;
    filteredTotalDebit = 0;

    for (var tx in transactions) {
      final amount = (tx['amount'] as num).toDouble();
      if (tx['type'] == 'debit') {
        filteredTotalDebit += amount;
      } else {
        filteredTotalCredit += amount;
      }
    }
  }
}
