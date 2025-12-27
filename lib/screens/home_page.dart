import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';
import 'settings_page.dart';
import 'goal_history_screen.dart';
import '../viewmodels/home_view_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final HomeViewModel _viewModel = HomeViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init();
  }

  void refreshData() {
    _viewModel.refreshData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _changeSummaryMonth(int months) {
    _viewModel.changeSummaryMonth(months);
  }

  void _resetSummaryMonth() {
    _viewModel.resetSummaryMonth();
  }

  Future<void> _syncMessages() async {
    final int newCount = await _viewModel.syncMessages();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newCount > 0
                ? (CMS.home['new_transaction_found'] as String).replaceFirst(
                  '{count}',
                  '$newCount',
                )
                : CMS.home['no_new_transaction']!,
          ),
          backgroundColor: newCount > 0 ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMonthlySummaryCard() {
    final now = DateTime.now();
    final isCurrentMonth =
        _viewModel.summaryMonth.year == now.year &&
        _viewModel.summaryMonth.month == now.month;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _changeSummaryMonth(-1),
                ),
                Text(
                  DateFormat.yMMMM().format(_viewModel.summaryMonth),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCurrentMonth)
                      IconButton(
                        icon: const Icon(Icons.restore, color: Colors.blue),
                        tooltip: "Reset to Current Month",
                        visualDensity: VisualDensity.compact,
                        onPressed: _resetSummaryMonth,
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right,
                        color:
                            isCurrentMonth
                                ? Colors.grey.withOpacity(0.5)
                                : null,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed:
                          isCurrentMonth ? null : () => _changeSummaryMonth(1),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      CMS.home['spends_label']!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.compactCurrency(
                        symbol: CMS.common['currency_symbol']!,
                      ).format(_viewModel.summaryData['expense']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ), // Vertical Divider
                Column(
                  children: [
                    Text(
                      CMS.home['credits_label']!,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.compactCurrency(
                        symbol: CMS.common['currency_symbol']!,
                      ).format(_viewModel.summaryData['income']),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingBills() {
    if (_viewModel.upcomingBills.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                CMS.home['upcoming_bills']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
              const Spacer(),
              Text(
                "${_viewModel.upcomingBills.length} ${CMS.home['upcoming_due']!}",
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._viewModel.upcomingBills.map((bill) {
            final date = DateTime.fromMillisecondsSinceEpoch(
              bill['nextBillDate'],
            );
            final days = date.difference(DateTime.now()).inDays;
            String dueText =
                days < 0 ? "Overdue" : (days == 0 ? "Today" : "in $days days");

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    bill['name'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "₹${bill['amount']} • $dueText",
                    style: TextStyle(
                      color: days < 0 ? Colors.red : Colors.grey[800],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CMS.home['add_menu_title']!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_card, color: Colors.blue),
                ),
                title: Text(CMS.home['add_menu_transaction']!),
                subtitle: Text(CMS.home['add_menu_transaction_sub']!),
                onTap: () async {
                  Navigator.pop(context); // Close sheet
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddTransactionScreen(),
                    ),
                  );
                  _viewModel.refreshData();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_fix_high, color: Colors.purple),
                ),
                title: Text(CMS.home['add_menu_pattern']!),
                subtitle: Text(CMS.home['add_menu_pattern_sub']!),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(initialIndex: 1),
                    ),
                  ).then((_) => _viewModel.refreshData());
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              "${CMS.home['greeting_prefix']!} ${_viewModel.userName}",
            ),
            actions: [
              IconButton(
                icon:
                    _viewModel.isSyncing
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh),
                onPressed: _viewModel.isSyncing ? null : _syncMessages,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddMenu(context),
            child: const Icon(Icons.add),
          ),
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                // Swiped Right -> Previous Month
                _changeSummaryMonth(-1);
              } else if (details.primaryVelocity! < 0) {
                // Swiped Left -> Next Month
                _changeSummaryMonth(1);
              }
            },
            child: RefreshIndicator(
              onRefresh: _syncMessages,
              child:
                  _viewModel.transactions.isEmpty
                      ? ListView(
                        children: [
                          const SizedBox(height: 200),
                          Center(
                            child: Text(
                              CMS.home['no_transactions']!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                      : ListView.builder(
                        // +1 Summary, +1 Budget, +1 Bills, +1 Goals, +Transactions
                        itemCount: _viewModel.transactions.length + 4,
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildMonthlySummaryCard();

                          if (index == 1) return _buildBudgetCard();
                          if (index == 2) return _buildUpcomingBills();
                          if (index == 3) return _buildGoalsSection();

                          // Adjust index for transactions (4 items before list)
                          final txIndex = index - 4;
                          final tx = _viewModel.transactions[txIndex];
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
                            final prevTx = _viewModel.transactions[txIndex - 1];
                            final prevDate =
                                DateTime.fromMillisecondsSinceEpoch(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              tx['categoryName'] ?? "Uncategorized",
                            ),
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
                                      (context) => TransactionDetailScreen(
                                        transaction: tx,
                                      ),
                                ),
                              );
                              _viewModel.refreshData();
                            },
                          );

                          if (showHeader) {
                            // Get the total for this day from our map
                            final dailyTotal =
                                _viewModel.dailyTotals[normalizedDate] ?? 0.0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    24,
                                    16,
                                    8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
          ),
        );
      },
    );
  }

  Widget _buildBudgetCard() {
    if (_viewModel.monthlyBudget <= 0) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.blue.shade50,
        child: InkWell(
          onTap: _showBudgetEditor,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  CMS.home['monthly_budget_set']!,
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
    double currentMonthSpent = 0.0;

    for (var tx in _viewModel.transactions) {
      if (tx['type'] == 'debit' || tx['type'] == 'expense') {
        currentMonthSpent += (tx['amount'] as num).toDouble();
      }
    }

    final progress = currentMonthSpent / _viewModel.monthlyBudget;
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
                Row(
                  children: [
                    Text(
                      "${CMS.home['monthly_budget_title']!} (${DateFormat.MMMM().format(_viewModel.summaryMonth)})",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.grey,
                      ),
                      splashRadius: 20,
                      onPressed: _showBudgetEditor,
                    ),
                  ],
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
                  "${CMS.home['spent_label']!}₹${currentMonthSpent.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  "${CMS.home['remaining_label']!}₹${(_viewModel.monthlyBudget - currentMonthSpent).toStringAsFixed(0)}",
                  style: TextStyle(
                    color:
                        (_viewModel.monthlyBudget - currentMonthSpent) < 0
                            ? Colors.red
                            : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${CMS.home['limit_label']!}₹${_viewModel.monthlyBudget.toStringAsFixed(0)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // --- Category Breakdown ---
            if (_viewModel.categories.any(
              (c) => (c['budgetLimit'] ?? 0) > 0,
            )) ...[
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
              ..._viewModel.categories.where((c) => (c['budgetLimit'] ?? 0) > 0).map((
                cat,
              ) {
                double catSpent = 0.0;
                for (var tx in _viewModel.transactions) {
                  if (tx['categoryId'] == cat['id'] &&
                      (tx['type'] == 'debit' || tx['type'] == 'expense')) {
                    catSpent += (tx['amount'] as num).toDouble();
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
                                        ? Color(cat['color']).withAlpha(51)
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

  Widget _buildGoalsSection() {
    final activeGoals =
        _viewModel.goals.where((g) => (g['isArchived'] ?? 0) == 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: const Text(
            "Savings Goals",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: activeGoals.length + 1, // +1 for Add Card
            itemBuilder: (context, index) {
              if (index == activeGoals.length) {
                // ADD GOAL CARD
                return GestureDetector(
                  onTap: _showAddGoalDialog,
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_circle,
                          color: Colors.blue,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "New Goal",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final goal = activeGoals[index];
              final currentAmount = (goal['savedAmount'] as num).toDouble();
              final targetAmount = (goal['targetAmount'] as num).toDouble();

              final progress =
                  targetAmount > 0
                      ? (currentAmount / targetAmount).clamp(0.0, 1.0)
                      : 0.0;
              final colorInt = goal['color'];
              final color = colorInt != null ? Color(colorInt) : Colors.blue;

              return GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalHistoryScreen(goal: goal),
                    ),
                  );
                  _viewModel.refreshData();
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
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
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withAlpha(51),
                            child: Icon(Icons.savings, size: 16, color: color),
                          ),
                          const Spacer(),
                          Text(
                            "${(progress * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        goal['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹${NumberFormat.compact().format(currentAmount)} / ${NumberFormat.compact().format(targetAmount)}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        color: color,
                        backgroundColor: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showAddGoalDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    Color selectedColor = Colors.blue;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(CMS.home['create_goal_title']!),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: CMS.home['create_goal_name']!,
                        prefixIcon: const Icon(Icons.flag),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: CMS.home['create_goal_amount']!,
                        prefixIcon: const Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            [
                              Colors.blue,
                              Colors.purple,
                              Colors.green,
                              Colors.orange,
                              Colors.red,
                              Colors.teal,
                            ].map((c) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() => selectedColor = c);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border:
                                          selectedColor == c
                                              ? Border.all(
                                                color: Colors.black,
                                                width: 2,
                                              )
                                              : null,
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: c,
                                      radius: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(CMS.common['cancel']!),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty &&
                          amountController.text.isNotEmpty) {
                        final target =
                            double.tryParse(amountController.text) ?? 0;
                        await _viewModel.createGoal(
                          nameController.text,
                          target,
                          selectedColor.value,
                        );
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Text(CMS.home['create_goal_btn']!),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showBudgetEditor() {
    final totalController = TextEditingController(
      text:
          _viewModel.monthlyBudget > 0
              ? _viewModel.monthlyBudget.toStringAsFixed(0)
              : '',
    );
    final Map<int, TextEditingController> catControllers = {};
    for (var cat in _viewModel.categories) {
      final limit = (cat['budgetLimit'] as num?)?.toDouble() ?? 0.0;
      catControllers[cat['id']] = TextEditingController(
        text: limit > 0 ? limit.toStringAsFixed(0) : '',
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (CMS.home['budget_editor_title'] as String)
                            .replaceFirst(
                              '{month}',
                              DateFormat.MMMM().format(_viewModel.summaryMonth),
                            ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          final total =
                              double.tryParse(totalController.text) ?? 0.0;
                          final Map<int, double> catBudgets = {};

                          for (var entry in catControllers.entries) {
                            final catTotal =
                                double.tryParse(entry.value.text) ?? 0.0;
                            catBudgets[entry.key] = catTotal;
                          }

                          await _viewModel.saveBudgetSettings(
                            total,
                            catBudgets,
                          );

                          if (mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      TextField(
                        controller: totalController,
                        decoration: InputDecoration(
                          labelText: CMS.home['budget_total_label']!,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.account_balance_wallet),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        CMS.home['budget_sublimits_label']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._viewModel.categories.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(
                                  cat['color'] ?? Colors.grey.value,
                                ),
                                radius: 16,
                                child: Text(
                                  cat['name'][0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cat['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: catControllers[cat['id']],
                                  decoration: const InputDecoration(
                                    prefixText: "₹",
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 50), // Spacing for keyboard
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
