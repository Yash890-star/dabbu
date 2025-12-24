import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/message_helper.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String _userName = "";
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _categories = []; // <--- Store categories
  Map<DateTime, double> _dailyTotals = {}; // <--- New Map to store daily sums
  double _monthlyBudget = 0.0;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initDefaults();
    refreshData();
  }

  Future<void> _initDefaults() async {
    await DatabaseHelper.instance.seedDefaultCategories();
    if (mounted) refreshData(); // Refresh to show new categories
  }

  Future<void> refreshData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = await DatabaseHelper.instance.getTransactionsWithDetails();
    final cats =
        await DatabaseHelper.instance.getCategories(); // <--- Fetch cats

    final budget = prefs.getDouble('monthly_budget') ?? 0.0;

    // Calculate totals whenever data loads
    final totals = _calculateDailyTotals(data);

    if (mounted) {
      setState(() {
        _userName = prefs.getString('userName') ?? "User";
        _transactions = data;
        _categories = cats;
        _dailyTotals = totals;
        _monthlyBudget = budget;
      });
    }
  }

  // --- NEW: Helper to sum amounts per day ---
  Map<DateTime, double> _calculateDailyTotals(List<Map<String, dynamic>> txs) {
    Map<DateTime, double> totals = {};
    for (var tx in txs) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      final key = DateTime(
        date.year,
        date.month,
        date.day,
      ); // Normalize to midnight

      if (!totals.containsKey(key)) {
        totals[key] = 0.0;
      }
      // We sum the amounts. You can choose to subtract credits if you want "Net Spend"
      // For now, this shows "Total Activity" (Volume)
      totals[key] = totals[key]! + (tx['amount'] as num).toDouble();
    }
    return totals;
  }

  Future<void> _syncMessages() async {
    setState(() => _isSyncing = true);
    final helper = MessageHelper();
    int newCount = await helper.processNewMessages(lookBackDays: 60);
    await refreshData();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newCount > 0
                ? "Found $newCount new transactions!"
                : "No new transactions found.",
          ),
          backgroundColor: newCount > 0 ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Date Helpers ---
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) return "Today";
    if (dateToCheck == yesterday) return "Yesterday";
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hello, $_userName"),
        actions: [
          IconButton(
            icon:
                _isSyncing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : _syncMessages,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
          refreshData(); // Refresh list on return
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _syncMessages,
        child:
            _transactions.isEmpty
                ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Text(
                        "No transactions yet.\nPull down to scan.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
                : ListView.builder(
                  // +1 for the Budget Card at the top
                  itemCount: _transactions.length + 1,
                  itemBuilder: (context, index) {
                    // Index 0 is now the Budget Card
                    if (index == 0) {
                      return _buildBudgetCard();
                    }

                    // Adjust index for transactions
                    final txIndex = index - 1;
                    final tx = _transactions[txIndex];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      tx['date'],
                    );
                    final normalizedDate = DateTime(
                      date.year,
                      date.month,
                      date.day,
                    );

                    bool showHeader = false;
                    if (txIndex == 0) {
                      showHeader = true;
                    } else {
                      final prevTx = _transactions[txIndex - 1];
                      final prevDate = DateTime.fromMillisecondsSinceEpoch(
                        prevTx['date'],
                      );
                      if (!_isSameDay(date, prevDate)) {
                        showHeader = true;
                      }
                    }

                    // Build the Transaction Tile
                    final tile = ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            tx['type'] == 'credit'
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                        child: Icon(
                          tx['type'] == 'credit'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color:
                              tx['type'] == 'credit'
                                  ? Colors.green
                                  : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        tx['patternName'] ?? tx['sender'] ?? "Unknown",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(tx['categoryName'] ?? "Uncategorized"),
                      trailing: Text(
                        "${tx['amount']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              tx['type'] == 'credit'
                                  ? Colors.green
                                  : Colors.red,
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
                        refreshData();
                      },
                    );

                    if (showHeader) {
                      // Get the total for this day from our map
                      final dailyTotal = _dailyTotals[normalizedDate] ?? 0.0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            // CHANGED: Row to show Date on Left, Total on Right
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDateHeader(date),
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  NumberFormat.currency(
                                    symbol: "INR ",
                                    locale: "en_IN",
                                  ).format(dailyTotal),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          tile,
                        ],
                      );
                    } else {
                      return tile;
                    }
                  },
                ),
      ),
    );
  }

  Widget _buildBudgetCard() {
    if (_monthlyBudget <= 0) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.blue.shade50,
        child: InkWell(
          onTap: () {
            // Navigate to Settings -> General Tab (index 0)
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsPage(),
              ), // Settings handles its own defaults
            ).then((_) => refreshData());
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  "Set a Monthly Budget",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 1. Calculate this month's spending
    final now = DateTime.now();
    double currentMonthSpent = 0.0;

    for (var tx in _transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      if (date.year == now.year && date.month == now.month) {
        if (tx['type'] == 'debit' || tx['type'] == 'expense') {
          currentMonthSpent += (tx['amount'] as num).toDouble();
        }
      }
    }

    final progress = currentMonthSpent / _monthlyBudget;
    final color =
        progress > 1.0
            ? Colors.red
            : progress > 0.8
            ? Colors.orange
            : Colors.green;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- Global Budget Progress ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Monthly Budget (${DateFormat.MMMM().format(now)})",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "${(progress * 100).toStringAsFixed(0)}%",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress > 1 ? 1 : progress,
              color: color,
              backgroundColor: Colors.grey.shade200,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Spent: ₹${currentMonthSpent.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  "Remaining: ₹${(_monthlyBudget - currentMonthSpent).toStringAsFixed(0)}",
                  style: TextStyle(
                    color:
                        (_monthlyBudget - currentMonthSpent) < 0
                            ? Colors.red
                            : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Limit: ₹${_monthlyBudget.toStringAsFixed(0)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // --- Category Breakdown ---
            if (_categories.any((c) => (c['budgetLimit'] ?? 0) > 0)) ...[
              const Divider(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Category Budgets",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ..._categories.where((c) => (c['budgetLimit'] ?? 0) > 0).map((
                cat,
              ) {
                double catSpent = 0.0;
                for (var tx in _transactions) {
                  final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
                  if (date.year == now.year && date.month == now.month) {
                    if (tx['categoryId'] == cat['id'] &&
                        (tx['type'] == 'debit' || tx['type'] == 'expense')) {
                      catSpent += (tx['amount'] as num).toDouble();
                    }
                  }
                }

                final catLimit = (cat['budgetLimit'] as num).toDouble();
                final catProgress = catSpent / catLimit;
                final catColor =
                    catProgress > 1.0
                        ? Colors.red
                        : catProgress > 0.8
                        ? Colors.orange
                        : Colors.blue;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05), // Neutral background
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor:
                                    cat['color'] != null
                                        ? Color(cat['color']).withOpacity(0.2)
                                        : Colors.grey.shade200,
                                child: Icon(
                                  Icons.category,
                                  size: 12,
                                  color:
                                      cat['color'] != null
                                          ? Color(cat['color'])
                                          : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cat['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "₹${catSpent.toStringAsFixed(0)} / ₹${catLimit.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: catProgress > 1 ? 1 : catProgress,
                        color: catColor,
                        backgroundColor:
                            Colors
                                .white, // Better contrast against the colored bg
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
