import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import 'transaction_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // Data for the month
  Map<int, double> _dailyNet = {}; // Day -> Net Amount (Debit - Credit)
  Map<int, List<Map<String, dynamic>>> _dailyTransactions = {};
  double _maxNet = 1.0; // For scaling opacity

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMonthData();
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedDate = DateTime(
        _focusedDate.year,
        _focusedDate.month + offset,
        1,
      );
      // Reset selection if moving to a different month
      // Or keep it if we want, but usually resetting to null or clamping is safer.
      // Let's default to the 1st of the new month or today if matches.
      _selectedDate = _focusedDate;
    });
    _fetchMonthData();
  }

  Future<void> _fetchMonthData() async {
    setState(() => _isLoading = true);

    final start = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final end = DateTime(
      _focusedDate.year,
      _focusedDate.month + 1,
      0,
      23,
      59,
      59,
    );

    final data = await DatabaseHelper.instance.getFilteredTransactions(
      startEpoch: start.millisecondsSinceEpoch,
      endEpoch: end.millisecondsSinceEpoch,
    );

    // Process Data
    Map<int, double> tempNet = {};
    Map<int, List<Map<String, dynamic>>> tempTxs = {};
    double tempMax = 0;

    for (var tx in data) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      final day = date.day;
      final amount = (tx['amount'] as num).toDouble();
      final isDebit = tx['type'] == 'debit';

      // Aggregate Net
      // Debit is +ve for expense logic in prompt "sum debit - credit"
      // Wait, prompt says: "debit - credit is 0 or positive the bg should be red"
      // "negative (that is credit is higher) we should show the bg as green"
      // So Net = Debit - Credit.
      double currentNet = tempNet[day] ?? 0.0;
      if (isDebit) {
        currentNet += amount;
      } else {
        currentNet -= amount;
      }
      tempNet[day] = currentNet;

      // Track Max for Opacity (using absolute value)
      if (currentNet.abs() > tempMax) {
        tempMax = currentNet.abs();
      }

      // Store Transaction
      if (tempTxs[day] == null) tempTxs[day] = [];
      tempTxs[day]!.add(tx);
    }

    if (mounted) {
      setState(() {
        _dailyNet = tempNet;
        _dailyTransactions = tempTxs;
        _maxNet = tempMax == 0 ? 1.0 : tempMax; // Avoid division by zero
        _isLoading = false;
      });
    }
  }

  Color _getDayColor(int day) {
    if (!_dailyNet.containsKey(day)) return Colors.white;

    final net = _dailyNet[day]!;
    // 0 is also Red (lighter red) per prompt: "sum debit - credit is 0 or positive the bg should be red"
    // Wait, if it's EXACTLY 0 because of NO data, it's white. Handled by containKey check.
    // If it's 0 because Debit = Credit, it enters this block.

    // Calculate intensity 0.2 to 1.0
    double intensity = (net.abs() / _maxNet).clamp(0.2, 1.0);

    // Explicit 0 check for safety, though net >= 0 covers it.
    if (net >= 0) {
      return Colors.red.withOpacity(intensity);
    } else {
      return Colors.green.withOpacity(intensity);
    }
  }

  Color _getTextColor(Color bg) {
    if (bg == Colors.white) return Colors.black87;
    // Simple luminance check or just assume dark bg for high intensity?
    // Let's check opacity. If opacity is low (< 0.5), black text. Else white.
    return bg.opacity > 0.5 ? Colors.white : Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    // Calculate weekday offset (0 = Monday, etc. Adjust for UI if starting Sunday)
    // Standard calendar usually starts Sunday or Monday. Let's do Sunday start?
    // Or Monday? Intl usually defaults to standard. Let's assume Mon=1.
    // Let's create a Sunday-based grid for standard feel.
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday % 7; // Su=0, Mo=1, ... Sa=6.
    // Wait, DateTime.weekday is Mon=1 ... Sun=7.
    // If we want Sunday start: Sun=0. So offset = (weekday % 7). (7%7=0 for Sun).

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Calendar Heat Map",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchMonthData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMonthData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Month Navigator
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      DateFormat.yMMMM().format(_focusedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Weekday Headers
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      ["S", "M", "T", "W", "T", "F", "S"]
                          .map(
                            (d) => Text(
                              d,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),

            // 3. Calendar Grid
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index < weekdayOffset) return const SizedBox.shrink();

                    final day = index - weekdayOffset + 1;
                    final date = DateTime(
                      _focusedDate.year,
                      _focusedDate.month,
                      day,
                    );
                    final isSelected =
                        day == _selectedDate.day &&
                        _focusedDate.month == _selectedDate.month &&
                        _focusedDate.year == _selectedDate.year;

                    final bgColor = _getDayColor(day);
                    final textColor = _getTextColor(bgColor);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              isSelected
                                  ? Border.all(color: Colors.black, width: 2)
                                  : Border.all(
                                    color: Colors.grey.shade200,
                                    width: 0.5,
                                  ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "$day",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }, childCount: daysInMonth + weekdayOffset),
                ),
              ),

            if (!_isLoading) ...[
              const SliverToBoxAdapter(child: Divider(height: 1)),

              // 4. Selected Day Details Header
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Transactions for ${DateFormat.yMMMd().format(_selectedDate)}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 5. Transaction List
              _buildTransactionSliver(),
            ],

            // Extra padding at bottom
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSliver() {
    final day = _selectedDate.day;
    final txs = _dailyTransactions[day];

    if (txs == null || txs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text(
              "No transactions on this date.",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final tx = txs[index];
        final isCredit = tx['type'] == 'credit';

        return Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                backgroundColor:
                    isCredit
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              title: Text(tx['patternName'] ?? tx['sender'] ?? "Unknown"),
              subtitle: Text(tx['categoryName'] ?? "Uncategorized"),
              trailing: Text(
                "${tx['amount']}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => TransactionDetailScreen(transaction: tx),
                  ),
                );
                _fetchMonthData(); // Refresh on return
              },
            ),
            const Divider(height: 1),
          ],
        );
      }, childCount: txs.length),
    );
  }
}
