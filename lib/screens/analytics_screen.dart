import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // --- Filter State ---
  String _timeFrame = 'Month';
  DateTime _focusedDate = DateTime.now();
  int? _selectedCategoryId;
  int? _selectedPatternId;

  // --- Data State ---
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _allPatterns = [];

  // New: Pre-calculated summary for the chart & legend
  List<_CategorySummary> _categorySummaries = [];

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
    setState(() {
      _allCategories = cats;
      _allPatterns = pats;
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

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final (start, end) = _getDateRange();

    final data = await DatabaseHelper.instance.getFilteredTransactions(
      startEpoch: start,
      endEpoch: end,
      categoryId: _selectedCategoryId,
      patternId: _selectedPatternId,
    );

    // --- NEW: Calculate Summaries Here ---
    Map<String, double> totals = {};
    Map<String, Color> colors = {};
    double totalExpense = 0;

    for (var tx in data) {
      if (tx['type'] == 'debit') {
        final catName = tx['categoryName'] ?? 'Uncategorized';
        final amount = (tx['amount'] as num).toDouble();
        totalExpense += amount;

        totals[catName] = (totals[catName] ?? 0) + amount;

        if (!colors.containsKey(catName)) {
          int? colorInt = tx['categoryColor'];
          colors[catName] = colorInt != null ? Color(colorInt) : Colors.grey;
        }
      }
    }

    // Convert map to list of objects and sort by highest spend
    List<_CategorySummary> summaries =
        totals.entries.map((e) {
          return _CategorySummary(
            name: e.key,
            amount: e.value,
            color: colors[e.key] ?? Colors.grey,
            percentage: totalExpense == 0 ? 0 : (e.value / totalExpense) * 100,
          );
        }).toList();

    summaries.sort((a, b) => b.amount.compareTo(a.amount));

    if (mounted) {
      setState(() {
        _transactions = data;
        _categorySummaries = summaries;
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
    double totalSpend = _transactions
        .where((t) => t['type'] == 'debit')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num));

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
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT SIDE: Chart
                        Expanded(
                          flex: 4,
                          child: SizedBox(
                            height: 160,
                            // CHANGE 1: Explicitly center align elements in the Stack
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
                                // CHANGE 2: The Text in the middle
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Total",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2), // Small gap
                                    Text(
                                      NumberFormat.compact().format(totalSpend),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
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
            value: _selectedCategoryId,
            items: _allCategories,
            idKey: 'id',
            nameKey: 'name',
            fetchItems: () => DatabaseHelper.instance.getCategories(),
            onChanged: (val) {
              setState(() => _selectedCategoryId = val);
              _fetchData();
            },
          ),
          const SizedBox(width: 10),
          _buildFilterChip<int>(
            label: "Method",
            value: _selectedPatternId,
            items: _allPatterns,
            idKey: 'id',
            nameKey: 'name',
            fetchItems:
                () => DatabaseHelper.instance.database.then(
                  (d) => d.query('patterns'),
                ),
            onChanged: (val) {
              setState(() => _selectedPatternId = val);
              _fetchData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required String idKey,
    required String nameKey,
    required Function(T?) onChanged,
    required Future<List<Map<String, dynamic>>> Function() fetchItems,
  }) {
    String labelText = "All ${label}s";
    if (value != null && items.isNotEmpty) {
      try {
        final found = items.firstWhere((e) => e[idKey] == value);
        labelText = found[nameKey];
      } catch (e) {}
    }

    return GestureDetector(
      onTap: () async {
        final freshItems = await fetchItems();
        if (!mounted) return;
        final result = await showDialog<T>(
          context: context,
          builder:
              (ctx) => SimpleDialog(
                title: Text("Select $label"),
                children: [
                  SimpleDialogOption(
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text("All"),
                    ),
                    onPressed: () => Navigator.pop(ctx, null),
                  ),
                  ...freshItems.map(
                    (item) => SimpleDialogOption(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(item[nameKey]),
                      ),
                      onPressed: () => Navigator.pop(ctx, item[idKey]),
                    ),
                  ),
                ],
              ),
        );
        onChanged(result);
        setState(() {
          if (label == "Category") _allCategories = freshItems;
          if (label == "Method") _allPatterns = freshItems;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: value != null ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value != null ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Text(
              labelText,
              style: TextStyle(
                color: value != null ? Colors.blue.shade700 : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: value != null ? Colors.blue : Colors.grey,
            ),
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
