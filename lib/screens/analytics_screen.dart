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
  String _timeFrame = 'Month'; // 'Month', 'Week', 'Day'
  DateTime _focusedDate = DateTime.now(); // The date we are looking at
  int? _selectedCategoryId;
  int? _selectedPatternId;

  // --- Data State ---
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _allCategories = [];
  List<Map<String, dynamic>> _allPatterns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _fetchData();
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

  Future<void> _refreshAll() async {
    // Reload categories and patterns in case settings changed
    await _loadFilters();
    // Reload transactions in case new SMS were parsed
    await _fetchData();
  }

  // --- Date Calculation Logic ---
  (int, int) _getDateRange() {
    DateTime start, end;

    // Reset to start of day for cleaner calculations
    final date = DateTime(
      _focusedDate.year,
      _focusedDate.month,
      _focusedDate.day,
    );

    if (_timeFrame == 'Day') {
      start = date;
      end = date.add(const Duration(hours: 23, minutes: 59, seconds: 59));
    } else if (_timeFrame == 'Week') {
      // Find Monday of this week
      start = date.subtract(Duration(days: date.weekday - 1));
      end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
    } else {
      // Month (Default)
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

    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  // --- Chart Data Preparation ---
  List<PieChartSectionData> _getChartSections() {
    if (_transactions.isEmpty) return [];

    // Group by Category
    Map<String, double> totals = {};
    Map<String, Color> colors = {};

    for (var tx in _transactions) {
      // Only chart Debits (Expenses)
      if (tx['type'] == 'debit') {
        final catName = tx['categoryName'] ?? 'Uncategorized';
        final amount = (tx['amount'] as num).toDouble();

        totals[catName] = (totals[catName] ?? 0) + amount;

        // Handle Color
        if (!colors.containsKey(catName)) {
          int? colorInt = tx['categoryColor'];
          colors[catName] = colorInt != null ? Color(colorInt) : Colors.grey;
        }
      }
    }

    final totalExpense = totals.values.fold(0.0, (sum, item) => sum + item);

    return totals.entries.map((entry) {
      final percentage = (entry.value / totalExpense) * 100;
      return PieChartSectionData(
        color: colors[entry.key],
        value: entry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
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
  @override
  Widget build(BuildContext context) {
    double totalSpend = _transactions
        .where((t) => t['type'] == 'debit')
        .fold(0.0, (sum, t) => sum + (t['amount'] as num));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
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
          physics:
              const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works even if list is short
          children: [
            // 1. TIME CONTROLS
            Padding(
              padding: const EdgeInsets.all(8.0),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                        items:
                            ['Day', 'Week', 'Month']
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          setState(() => _timeFrame = val!);
                          _fetchData();
                        },
                      ),
                      Text(
                        _getDateLabel(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeDate(1),
                  ),
                ],
              ),
            ),

            // 2. FILTER DROPDOWNS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),

            const Divider(),

            // 3. CHART SECTION
            if (_isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_transactions.isEmpty)
              const SizedBox(
                height: 200,
                child: Center(child: Text("No transactions found")),
              )
            else ...[
              SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sections: _getChartSections(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                    Center(
                      child: Text(
                        "Total\n${totalSpend.toStringAsFixed(0)}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // 4. TRANSACTION LIST
              // We map the items directly into the parent ListView to avoid nesting issues
              ..._transactions.map((tx) {
                final isCredit = tx['type'] == 'credit';
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor:
                        isCredit ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 16,
                      color: isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(tx['sender'] ?? "Unknown"),
                  subtitle: Text(
                    "${DateFormat.MMMd().format(DateTime.fromMillisecondsSinceEpoch(tx['date']))} • ${tx['categoryName'] ?? 'Uncategorized'}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    "${tx['amount']}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                );
              }),

              // Add some padding at the bottom so the last item isn't covered by FAB or Nav Bar
              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }

  // Custom Filter Chip Widget helper
  Widget _buildFilterChip<T>({
    required String label,
    required T? value,
    required List<Map<String, dynamic>> items,
    required String idKey,
    required String nameKey,
    required Function(T?) onChanged,
    // Add this new line:
    required Future<List<Map<String, dynamic>>> Function() fetchItems,
  }) {
    // Helper to find the name of the currently selected item
    String labelText = "All ${label}s";

    // Check if we have a selected value and find its name
    if (value != null && items.isNotEmpty) {
      try {
        final found = items.firstWhere((e) => e[idKey] == value);
        labelText = found[nameKey];
      } catch (e) {
        // Fallback if item not found (e.g. deleted)
      }
    }

    return InputChip(
      label: Text(labelText),
      selected: value != null,
      onDeleted: value != null ? () => onChanged(null) : null,
      onPressed: () async {
        // 1. FETCH FRESH DATA IMMEDIATELY
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
                      padding: EdgeInsets.all(8.0),
                      child: Text("All"),
                    ),
                    onPressed: () => Navigator.pop(ctx, null),
                  ),
                  ...freshItems.map(
                    (item) => SimpleDialogOption(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(item[nameKey]),
                      ),
                      onPressed: () => Navigator.pop(ctx, item[idKey]),
                    ),
                  ),
                ],
              ),
        );

        // Update if a selection was made
        if (result != null || (result == null && value != null)) {
          onChanged(result);

          // Update the local list immediately so the label updates correctly
          setState(() {
            if (label == "Category") _allCategories = freshItems;
            if (label == "Method") _allPatterns = freshItems;
          });
        }
      },
    );
  }
}
