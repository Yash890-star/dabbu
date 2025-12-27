import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import 'transaction_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // --- Filter State ---
  String _timeFrame = 'Month';
  DateTime _focusedDate = DateTime.now();
  List<int> _selectedCategoryIds = [];
  List<int> _selectedPatternIds = [];

  // --- Data State ---
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _allPatterns = [];

  // New: Chart Filter State
  String _transactionType = 'debit'; // 'debit' or 'credit'

  // New: Pre-calculated summary for the chart & legend
  List<_CategorySummary> _categorySummaries = [];

  // New: Insights State
  List<_InsightItem> _insights = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _fetchData();
  }

  Future<void> _refreshAll() async {
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
      'name': 'Manual Transactions',
      'senderId': 'MANUAL', // Dummy values for required fields
      'patternRegex': '',
      'messageType': 'debit',
    });

    setState(() {
      _allCategories = cats;
      _allPatterns = modifiablePatterns;
    });
  }

  // --- Date Logic (Same as before) ---
  (int, int) _getDateRange() {
    DateTime start, end;
    final date = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      _focusedDate.day,
    );

    if (_timeFrame == 'Day') {
      start = date;
      end = date.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else if (_timeFrame == 'Week') {
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
    final date = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      _focusedDate.day,
    );

    if (_timeFrame == 'Day') {
      // Prev Day
      final prevDate = date.subtract(const Duration(days: 1));
      start = prevDate;
      end = prevDate.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else if (_timeFrame == 'Week') {
      // Prev Week
      final startCurrent = date.subtract(Duration(days: date.weekday - 1));
      start = startCurrent.subtract(const Duration(days: 7));
      end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else {
      // Prev Month
      // Go to first day of current month, subtract 1 day to get last day of prev month, then find start.
      // Actually simpler: Month - 1
      start = DateTime(date.year, date.month - 1, 1);
      end = DateTime(date.year, date.month, 0, 23, 59, 59);
    }
    return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final (start, end) = _getDateRange();
    final (startPrev, endPrev) = _getPreviousDateRange();

    final db = DatabaseHelper.instance;

    // 1. Current Period Data
    final data = await db.getFilteredTransactions(
      startEpoch: start,
      endEpoch: end,
      categoryIds: _selectedCategoryIds,
      patternIds: _selectedPatternIds,
      type: _transactionType,
    );

    // 2. Previous Period Data (For Insights)
    final prevData = await db.getFilteredTransactions(
      startEpoch: startPrev,
      endEpoch: endPrev,
      categoryIds: _selectedCategoryIds,
      patternIds: _selectedPatternIds,
      type: _transactionType,
    );

    // --- NEW: Calculate Summaries & Insights ---
    Map<String, double> totals = {};
    Map<String, Color> colors = {};
    double totalFilterAmount = 0;

    // Process Current Data
    for (var tx in data) {
      // DB already filtered by type, so we can skip the check or keep it as sanity check.
      // Removing to trust DB and simplify.
      final catName = tx['categoryName'] ?? 'Uncategorized';
      final amount = (tx['amount'] as num).toDouble();
      totalFilterAmount += amount;
      totals[catName] = (totals[catName] ?? 0) + amount; // Current Total

      if (!colors.containsKey(catName)) {
        int? colorInt = tx['categoryColor'];
        colors[catName] = colorInt != null ? Color(colorInt) : Colors.grey;
      }
    }

    // Process Previous Data
    Map<String, double> prevTotals = {};
    for (var tx in prevData) {
      final catName = tx['categoryName'] ?? 'Uncategorized';
      final amount = (tx['amount'] as num).toDouble();
      prevTotals[catName] = (prevTotals[catName] ?? 0) + amount;
    }

    // Generate Insights
    List<_InsightItem> calculatedInsights = [];
    totals.forEach((catName, currentAmount) {
      final prevAmount = prevTotals[catName] ?? 0.0;
      if (prevAmount > 0) {
        // Only compare if we had spend previously
        final diff = currentAmount - prevAmount;
        final pctChange = (diff / prevAmount) * 100;

        // Filter out insignificant changes
        // Adjust threshold: Show if change is >= 5% OR absolute difference >= 50
        if (pctChange.abs() >= 5 || diff.abs() >= 50) {
          calculatedInsights.add(
            _InsightItem(
              categoryName: catName,
              currentAmount: currentAmount,
              prevAmount: prevAmount,
              percentageChange: pctChange,
              diffAmount: diff,
            ),
          );
        }
      } else if (currentAmount > 0 && prevAmount == 0) {
        // New Spend Category!
        calculatedInsights.add(
          _InsightItem(
            categoryName: catName,
            currentAmount: currentAmount,
            prevAmount: 0,
            percentageChange: 100, // Treat as 100% increase (or new)
            diffAmount: currentAmount,
          ),
        );
      }
    });

    // Check for "Savings" (Categories where spend dropped significantly)
    prevTotals.forEach((catName, prevAmount) {
      if (!totals.containsKey(catName) && prevAmount > 0) {
        // Stopped spending entirely!
        calculatedInsights.add(
          _InsightItem(
            categoryName: catName,
            currentAmount: 0,
            prevAmount: prevAmount,
            percentageChange: -100,
            diffAmount: -prevAmount,
          ),
        );
      }
    });

    // Sort by absolute impact (highest change amount)
    calculatedInsights.sort(
      (a, b) => b.diffAmount.abs().compareTo(a.diffAmount.abs()),
    );

    // Convert to Chart Data
    List<_CategorySummary> summaries =
        totals.entries.map((e) {
          return _CategorySummary(
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

    // Data is already filtered by DB now
    final filteredList = data;

    if (mounted) {
      setState(() {
        _transactions = filteredList;
        _categorySummaries = summaries;
        _insights = calculatedInsights;
        _isLoading = false;
      });
    }
  }

  // --- UI Helpers ---
  void _changeDate(int offset) {
    setState(() {
      if (_timeFrame == 'Day') {
        _focusedDate = _focusedDate.add(Duration(days: offset));
      } else if (_timeFrame == 'Week') {
        _focusedDate = _focusedDate.add(Duration(days: offset * 7));
      } else {
        _focusedDate = DateTime(
          _focusedDate.year,
          _focusedDate.month + offset,
          1,
        );
      }
    });
    _fetchData();
  }

  String _getDateLabel() {
    if (_timeFrame == 'Day') return DateFormat.yMMMd().format(_focusedDate);
    if (_timeFrame == 'Week') {
      final start = _focusedDate.subtract(
        Duration(days: _focusedDate.weekday - 1),
      );
      final end = start.add(const Duration(days: 6));
      return "${DateFormat.MMMd().format(start)} - ${DateFormat.MMMd().format(end)}";
    }
    return DateFormat.yMMMM().format(_focusedDate);
  }

  @override
  Widget build(BuildContext context) {
    double displayedTotal = _categorySummaries.fold(
      0.0,
      (sum, i) => sum + i.amount,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        title: const Text(
          "Spending Analytics",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. TIME CONTROLS
            _buildTimeControls(),

            const SizedBox(height: 16),

            // 1.5 TYPE TOGGLE (Expenses vs Income)
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'debit',
                    label: Text('Expenses'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment<String>(
                    value: 'credit',
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {_transactionType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _transactionType = newSelection.first;
                    _fetchData(); // Refresh chart with new type
                  });
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                    Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return _transactionType == 'debit'
                          ? Colors.red.shade100
                          : Colors.green.shade100;
                    }
                    return null;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                    Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.black;
                    }
                    return null;
                  }),
                ),
              ),
            ),

            // 1.8 INSIGHTS (MoM Comparison)
            if (_insights.isNotEmpty && !_isLoading) ...[
              const SizedBox(height: 16),
              const Text(
                "Insights",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _insights.length,
                  itemBuilder: (context, index) {
                    final insight = _insights[index];
                    final isPositive = insight.percentageChange > 0;
                    final isExpense = _transactionType == 'debit';

                    // Logic:
                    // Expense Increase (+) -> Bad (Red)
                    // Expense Decrease (-) -> Good (Green)
                    // Income Increase (+) -> Good (Green)
                    // Income Decrease (-) -> Bad (Red)

                    bool isGood;
                    if (isExpense) {
                      isGood = !isPositive; // Less expense is good
                    } else {
                      isGood = isPositive; // More income is good
                    }

                    final color = isGood ? Colors.green : Colors.red;
                    // Actually trending_up is always "up", so we use boolean to decide icon rotation or just specific icons.
                    // Let's use specific icons.
                    // arrow_drop_up is increase, arrow_drop_down is decrease.
                    final arrowIcon =
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward;

                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(arrowIcon, size: 16, color: color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  insight.categoryName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            "${isPositive ? '+' : ''}${insight.percentageChange.toStringAsFixed(0)}% vs last ${_timeFrame.toLowerCase()}",
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            "${NumberFormat.compact().format(insight.diffAmount)} (${NumberFormat.compact().format(insight.currentAmount)})",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 2. FILTERS
            _buildFilters(),

            const SizedBox(height: 16),

            // 3. MAIN DASHBOARD CARD (Split View)
            if (!_isLoading && _transactions.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child:
                    displayedTotal == 0
                        ? SizedBox(
                          height: 200,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _transactionType == 'debit'
                                      ? Icons.savings
                                      : Icons.work_off,
                                  size: 48,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _transactionType == 'debit'
                                      ? "No expenses yet! 🎉"
                                      : "No income found for this period. 💸",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Try a different date range",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // LEFT SIDE: Chart
                                Expanded(
                                  flex: 4,
                                  child: SizedBox(
                                    height: 160,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        PieChart(
                                          PieChartData(
                                            sections:
                                                _categorySummaries.map((item) {
                                                  return PieChartSectionData(
                                                    color: item.color,
                                                    value: item.amount,
                                                    title:
                                                        '', // Keep title empty to hide labels on the ring
                                                    radius: 25,
                                                    showTitle:
                                                        false, // Ensure no text renders on the chart itself
                                                  );
                                                }).toList(),
                                            centerSpaceRadius: 40,
                                            sectionsSpace:
                                                0, // Set to 0 for a solid ring, or keeping 2-4 is fine
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              "Total",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                                height: 1.0,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 2,
                                            ), // Small gap
                                            Text(
                                              NumberFormat.compact().format(
                                                displayedTotal,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                height: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // RIGHT SIDE: Legend / Details
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        _categorySummaries.take(5).map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12.0,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: item.color,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  "${item.percentage.toStringAsFixed(0)}%",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  NumberFormat.compact().format(
                                                    item.amount,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
              ),

            const SizedBox(height: 24),

            // 4. RECENT TRANSACTIONS HEADER
            if (_transactions.isNotEmpty) ...[
              const Text(
                "Recent Transactions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // TRANSACTION LIST
              ..._transactions.map((tx) {
                final isCredit = tx['type'] == 'credit';
                return Card(
                  // Use Cards for cleaner look
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isCredit
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 18,
                        color: isCredit ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      tx['patternName'] ?? tx['sender'] ?? "Unknown",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "${DateFormat.MMMd().format(DateTime.fromMillisecondsSinceEpoch(tx['date']))} • ${tx['categoryName'] ?? 'Uncategorized'}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: Text(
                      "${tx['amount']}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isCredit ? Colors.green : Colors.red,
                      ),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  TransactionDetailScreen(transaction: tx),
                        ),
                      );
                      // Refresh data when coming back (in case category was edited)
                      _refreshAll();
                    },
                  ),
                );
              }),
            ],

            if (!_isLoading && _transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: Center(
                  child: Text("No transactions found for this period"),
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // --- Widget Extract: Time Controls ---
  Widget _buildTimeControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDate(-1),
          ),
          Column(
            children: [
              DropdownButton<String>(
                value: _timeFrame,
                isDense: true,
                underline: Container(),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 16,
                ),
                items:
                    ['Day', 'Week', 'Month']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (val) {
                  setState(() => _timeFrame = val!);
                  _fetchData();
                },
              ),
              Text(
                _getDateLabel(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }

  // --- Widget Extract: Filters ---
  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip<int>(
            label: "Category",
            selectedIds: _selectedCategoryIds,
            items: _allCategories,
            idKey: 'id',
            nameKey: 'name',
            fetchItems: () => DatabaseHelper.instance.getCategories(),
            onChanged: (val) {
              setState(() => _selectedCategoryIds = val);
              _fetchData();
            },
          ),
          const SizedBox(width: 10),
          _buildFilterChip<int>(
            label: "Method",
            selectedIds: _selectedPatternIds,
            items: _allPatterns,
            idKey: 'id',
            nameKey: 'name',
            fetchItems: () async {
              final db = DatabaseHelper.instance;
              final pats = await db.database.then((d) => d.query('patterns'));
              final List<Map<String, dynamic>> modifiablePatterns = List.from(
                pats,
              );
              modifiablePatterns.add({
                'id': -1,
                'name': 'Manual Transactions',
                'senderId': 'MANUAL',
                'patternRegex': '',
                'messageType': 'debit',
              });
              return modifiablePatterns;
            },
            onChanged: (val) {
              setState(() => _selectedPatternIds = val);
              _fetchData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required List<int> selectedIds,
    required List<Map<String, dynamic>> items,
    required String idKey,
    required String nameKey,
    required Function(List<int>) onChanged,
    required Future<List<Map<String, dynamic>>> Function() fetchItems,
  }) {
    String labelText = "All ${label}s";

    if (selectedIds.isNotEmpty && items.isNotEmpty) {
      if (selectedIds.length == 1) {
        try {
          final found = items.firstWhere((e) => e[idKey] == selectedIds.first);
          labelText = found[nameKey];
        } catch (e) {}
      } else {
        labelText = "$label (${selectedIds.length})";
      }
    }

    final isSelected = selectedIds.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        final freshItems = await fetchItems();
        if (!mounted) return;

        // Create a mutable copy of selected IDs for the dialog state
        List<int> tempSelected = List.from(selectedIds);

        await showDialog(
          context: context,
          builder:
              (ctx) => StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: Text("Select $label"),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children:
                            freshItems.map((item) {
                              final id = item[idKey] as int;
                              final isChecked = tempSelected.contains(id);
                              return CheckboxListTile(
                                value: isChecked,
                                title: Text(item[nameKey]),
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      tempSelected.add(id);
                                    } else {
                                      tempSelected.remove(id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          // Clear selection means "All"
                          setDialogState(() {
                            tempSelected.clear();
                          });
                        },
                        child: const Text("Clear All"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          onChanged(tempSelected);
                          Navigator.pop(ctx);
                        },
                        child: const Text("Apply"),
                      ),
                    ],
                  );
                },
              ),
        );
      },
      child: Container(
        height: 40, // Match SegmentedButton height roughly
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(20), // Pill shape
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade500,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 18, color: Colors.black87),
              const SizedBox(width: 8),
            ],
            Text(
              labelText,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Colors.black87,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Simple Model Class for the Summary
class _CategorySummary {
  final String name;
  final double amount;
  final Color color;
  final double percentage;

  _CategorySummary({
    required this.name,
    required this.amount,
    required this.color,
    required this.percentage,
  });
}

class _InsightItem {
  final String categoryName;
  final double currentAmount;
  final double prevAmount;
  final double percentageChange;
  final double diffAmount;

  _InsightItem({
    required this.categoryName,
    required this.currentAmount,
    required this.prevAmount,
    required this.percentageChange,
    required this.diffAmount,
  });
}
