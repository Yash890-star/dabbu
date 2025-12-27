import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../viewmodels/analytics_view_model.dart';
import 'transaction_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsViewModel _viewModel = AnalyticsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        double displayedTotal = _viewModel.categorySummaries.fold(
          0.0,
          (sum, i) => sum + i.amount,
        );

        return Scaffold(
          backgroundColor: Colors.grey[50], // Light background for contrast
          appBar: AppBar(
            title: Text(
              CMS.analytics['title']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _viewModel.isLoading ? null : _viewModel.refreshAll,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _viewModel.refreshAll,
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
                    segments: [
                      ButtonSegment<String>(
                        value: 'debit',
                        label: Text(CMS.analytics['expenses_label']!),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      ButtonSegment<String>(
                        value: 'credit',
                        label: Text(CMS.analytics['income_label']!),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                    selected: {_viewModel.transactionType},
                    onSelectionChanged: (Set<String> newSelection) {
                      _viewModel.setTransactionType(newSelection.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return _viewModel.transactionType == 'debit'
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
                if (_viewModel.insights.isNotEmpty &&
                    !_viewModel.isLoading) ...[
                  const SizedBox(height: 16),
                  Text(
                    CMS.analytics['insights_title']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _viewModel.insights.length,
                      itemBuilder: (context, index) {
                        final insight = _viewModel.insights[index];
                        final isPositive = insight.percentageChange > 0;
                        final isExpense = _viewModel.transactionType == 'debit';

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
                        final arrowIcon =
                            isPositive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward;

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
                                    child: Icon(
                                      arrowIcon,
                                      size: 16,
                                      color: color,
                                    ),
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
                                "${isPositive ? '+' : ''}${insight.percentageChange.toStringAsFixed(0)}%${CMS.analytics['vs_last']!}${_viewModel.timeFrame.toLowerCase()}",
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
                if (!_viewModel.isLoading && _viewModel.transactions.isNotEmpty)
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
                                      _viewModel.transactionType == 'debit'
                                          ? Icons.savings
                                          : Icons.work_off,
                                      size: 48,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _viewModel.transactionType == 'debit'
                                          ? CMS.analytics['no_expenses_title']!
                                          : CMS.analytics['no_income_title']!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      CMS.analytics['try_different_date']!,
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
                                                    _viewModel.categorySummaries
                                                        .map((item) {
                                                          return PieChartSectionData(
                                                            color: item.color,
                                                            value: item.amount,
                                                            title: '',
                                                            radius: 25,
                                                            showTitle: false,
                                                          );
                                                        })
                                                        .toList(),
                                                centerSpaceRadius: 40,
                                                sectionsSpace: 0,
                                              ),
                                            ),
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  CMS.analytics['total_label']!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey,
                                                    height: 1.0,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
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
                                            _viewModel.categorySummaries
                                                .take(5)
                                                .map((item) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12.0,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 10,
                                                          height: 10,
                                                          decoration:
                                                              BoxDecoration(
                                                                color:
                                                                    item.color,
                                                                shape:
                                                                    BoxShape
                                                                        .circle,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            item.name,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Text(
                                                          "${item.percentage.toStringAsFixed(0)}%",
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          NumberFormat.compact()
                                                              .format(
                                                                item.amount,
                                                              ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                  ),

                const SizedBox(height: 24),

                // 4. RECENT TRANSACTIONS HEADER
                if (_viewModel.transactions.isNotEmpty) ...[
                  Text(
                    CMS.analytics['recent_transactions']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TRANSACTION LIST
                  ..._viewModel.transactions.map((tx) {
                    final isCredit = tx['type'] == 'credit';
                    return Card(
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
                            isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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
                          _viewModel.refreshAll();
                        },
                      ),
                    );
                  }),
                ],

                if (!_viewModel.isLoading && _viewModel.transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Center(
                      child: Text(CMS.analytics['no_transactions']!),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
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
            onPressed: () => _viewModel.changeDate(-1),
          ),
          Column(
            children: [
              DropdownButton<String>(
                value: _viewModel.timeFrame,
                isDense: true,
                underline: Container(),
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 16,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Day',
                    child: Text(CMS.analytics['time_day']!),
                  ),
                  DropdownMenuItem(
                    value: 'Week',
                    child: Text(CMS.analytics['time_week']!),
                  ),
                  DropdownMenuItem(
                    value: 'Month',
                    child: Text(CMS.analytics['time_month']!),
                  ),
                ],
                onChanged: (val) {
                  _viewModel.setTimeFrame(val!);
                },
              ),
              Text(
                _viewModel.getDateLabel(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _viewModel.changeDate(1),
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
            selectedIds: _viewModel.selectedCategoryIds,
            items: _viewModel.allCategories,
            idKey: 'id',
            nameKey: 'name',
            onChanged: (val) {
              _viewModel.updateCategoryFilter(val);
            },
          ),
          const SizedBox(width: 10),
          _buildFilterChip<int>(
            label: "Method",
            selectedIds: _viewModel.selectedPatternIds,
            items: _viewModel.allPatterns,
            idKey: 'id',
            nameKey: 'name',
            onChanged: (val) {
              _viewModel.updatePatternFilter(val);
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
        if (!mounted) return;

        // Use items directly from VM (already loaded)
        final freshItems = items;

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
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
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
