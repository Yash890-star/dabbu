import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../viewmodels/analytics_view_model.dart';
import 'transaction_detail_screen.dart';

import '../widgets/analytics/insight_block.dart';
import '../widgets/analytics/chart_block.dart';
import '../widgets/analytics/category_bento.dart';
import '../widgets/calendar/heatmap_block.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/fade_in_entry.dart';
import '../widgets/app_card.dart';
import '../widgets/analytics/sender_filter_block.dart';
import '../widgets/analytics/filtered_summary_block.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {
  final AnalyticsViewModel _viewModel = AnalyticsViewModel();

  @override
  bool get wantKeepAlive => true;

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

  // --- UI Helpers ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              CMS.analytics['title']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(
                  _viewModel.transactionType == 'credit'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color:
                      _viewModel.transactionType == 'credit'
                          ? AppColors.income
                          : AppColors.expense,
                ),
                onPressed: () {
                  _viewModel.setTransactionType(
                    _viewModel.transactionType == 'debit' ? 'credit' : 'debit',
                  );
                },
                tooltip: "Toggle Income/Expense",
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _viewModel.refreshAll,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Controls (Time Frame Presets)
                  // 1. Controls (Transaction Type Filter)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children:
                            ['Income', 'All', 'Expense'].map((label) {
                              String type = 'all';
                              if (label == 'Income') type = 'credit';
                              if (label == 'Expense') type = 'debit';

                              final isSelected =
                                  _viewModel.transactionType == type;
                              return GestureDetector(
                                onTap:
                                    () => _viewModel.setTransactionType(type),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                              : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Month Navigation & Heatmap
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed:
                            _viewModel.canGoPrevious
                                ? () => _viewModel.changeDate(-1)
                                : null,
                      ),
                      GestureDetector(
                        onTap: () => _viewModel.selectFullMonth(),
                        child: Text(
                          DateFormat.yMMMM().format(_viewModel.focusedDate),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            _viewModel.canGoNext
                                ? () => _viewModel.changeDate(1)
                                : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_viewModel.isLoading)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Calculate HeatMapBlock Height
                        // 1. Available width inside the AppCard = constraints.maxWidth - 32 (padding)
                        // 2. Grid Item Width = (innerW - 48 (6 gaps)) / 7
                        // 3. Grid Height = (ItemW * 6 rows) + 40 (5 gaps)
                        // 4. Total = 32 (padding) + 15 (header) + 12 (gap) + GridH
                        final innerWidth = constraints.maxWidth - 32;
                        final itemWidth = (innerWidth - 48) / 7;
                        final gridHeight = (itemWidth * 6) + 40;
                        final totalHeight = 32 + 15 + 12 + gridHeight;

                        return ShimmerLoading(
                          width: double.infinity,
                          height: totalHeight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        );
                      },
                    )
                  else
                    FadeInEntry(
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity! < 0) {
                            _viewModel.changeDate(1);
                          } else if (details.primaryVelocity! > 0) {
                            _viewModel.changeDate(-1);
                          }
                        },
                        child: HeatMapBlock(
                          focusedDate: _viewModel.focusedDate,
                          dailyNet: _viewModel.dailyNet,
                          maxNet: _viewModel.maxNet,
                          rangeStart: _viewModel.rangeStart,
                          rangeEnd: _viewModel.rangeEnd,
                          onDaySelected: _viewModel.onDaySelected,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 3. Category Breakdown (Collapsible Pie Chart)
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: const Text(
                        "Category Breakdown",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          _viewModel.isPieChartExpanded
                              ? null
                              : Text(
                                _viewModel.categorySummaries.isEmpty
                                    ? "No Data"
                                    : "Tap to view details",
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                      initiallyExpanded: _viewModel.isPieChartExpanded,
                      onExpansionChanged: (val) => _viewModel.togglePieChart(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child:
                              _viewModel.categorySummaries.isEmpty
                                  ? const Center(
                                    child: Text(
                                      "No transactions in selected range",
                                    ),
                                  )
                                  : ChartBlock(
                                    sections:
                                        _viewModel.categorySummaries
                                            .map(
                                              (s) => ChartSectionData(
                                                color: s.color,
                                                value: s.amount,
                                                percentage: s.percentage,
                                                title: s.name,
                                              ),
                                            )
                                            .toList(),
                                    totalAmount: _viewModel.categorySummaries
                                        .fold(0, (sum, i) => sum + i.amount),
                                  ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Insight Block
                  if (_viewModel.insights.isNotEmpty) ...[
                    FadeInEntry(child: _buildInsightBlock()),
                    const SizedBox(height: 16),
                  ],

                  // 5. Top Categories (Horizontal List)
                  if (_viewModel.categorySummaries.isNotEmpty) ...[
                    SizedBox(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Top Categories",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_viewModel.selectedCategoryIds.isNotEmpty)
                            TextButton(
                              onPressed: _viewModel.resetCategoryFilters,
                              child: const Text("Reset Filter"),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 140, // Height for CategoryBento
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _viewModel.categorySummaries.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = _viewModel.categorySummaries[index];
                          return SizedBox(
                            width: 160,
                            child: GestureDetector(
                              onTap: () {
                                _viewModel.toggleCategoryFilter(item.id);
                              },
                              child: CategoryBento(
                                categoryName: item.name,
                                amount: NumberFormat.compactCurrency(
                                  symbol: '₹',
                                ).format(item.amount),
                                percentage: item.percentage / 100,
                                color: item.color,
                                icon: Icons.pie_chart, // Placeholder icon
                                isSelected: _viewModel.selectedCategoryIds
                                    .contains(item.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 6. Name Filter (Pattern/Sender)
                  // 6. Controls Row (Filter, Sort, Reset) matched to mockup
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        // Filter Button (Toggle visibility or open menu - for now toggle sender list visibility?)
                        // User mock shows "Filter". Let's assume it expands the sender/category list.
                        // Or maybe it simply scrolls to them.
                        // For this iteration, let's make it show/hide the Sender Chips to be cleaner.

                        // Sort Button
                        OutlinedButton.icon(
                          onPressed: _showSortMenu,
                          icon: const Icon(Icons.sort, size: 16),
                          label: Text(
                            _getSortButtonLabel(_viewModel.sortOption),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurface,
                          ),
                        ),

                        const Spacer(),

                        // Reset Button
                        TextButton(
                          onPressed: _viewModel.resetAllFilters,
                          child: Text(
                            "Reset",
                            style: TextStyle(
                              color:
                                  (_viewModel.selectedNames.isNotEmpty ||
                                          _viewModel
                                              .selectedCategoryIds
                                              .isNotEmpty ||
                                          _viewModel.sortOption !=
                                              SortOption.dateDesc)
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).disabledColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sender Filter List (Keep visible for functional reasons, maybe animate later)
                  if (_viewModel.availableNames.isNotEmpty)
                    SenderFilterBlock(
                      availableSenders: _viewModel.availableNames,
                      selectedSenders: _viewModel.selectedNames,
                      onSenderTap: _viewModel.toggleNameFilter,
                    ),

                  const SizedBox(height: 16),

                  // 7. Filtered Summary Block (Updated Layout)
                  if (_viewModel.transactions.isNotEmpty) ...[
                    FilteredSummaryBlock(
                      dateLabel: _viewModel.getDateLabel(), // Add this
                      count: _viewModel.filteredCount,
                      totalCredit: _viewModel.filteredTotalCredit,
                      totalDebit: _viewModel.filteredTotalDebit,
                      currencySymbol: CMS.common['currency_symbol'] ?? '₹',
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 8. Transaction List Header & List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Transactions", // Or "The Ledger"
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_viewModel.rangeStart != null)
                        Text(
                          _viewModel.getDateLabel(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _buildTransactionList(
                    _viewModel.transactions,
                    shouldLimit:
                        _viewModel.selectedCategoryIds.isEmpty &&
                        _viewModel.transactionType == 'all',
                  ), // Pass showAll logic

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightBlock() {
    final insights = _viewModel.insights.take(2).toList();
    if (insights.isEmpty) return const SizedBox.shrink();

    return Row(
      children:
          insights.map((insight) {
            final isPositive = insight.percentageChange > 0;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InsightBlock(
                  title: insight.categoryName,
                  amount: NumberFormat.compactCurrency(
                    symbol: '₹',
                  ).format(insight.currentAmount),
                  subtitle:
                      "${isPositive ? '+' : ''}${insight.percentageChange.toStringAsFixed(1)}% vs prev",
                  isPositive: isPositive,
                  isGood: !isPositive, // Expense: Down is Good
                ),
              ),
            );
          }).toList(),
    );
  }

  bool _showAllTransactions = false;

  Widget _buildTransactionList(
    List<Map<String, dynamic>> txs, {
    bool shouldLimit = false,
  }) {
    if (txs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 8),
              Text(
                "No transactions found for this period",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final limit = 5;
    final doLimit = shouldLimit && !_showAllTransactions;
    final displayTxs = doLimit ? txs.take(limit).toList() : txs;

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayTxs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final tx = displayTxs[index];
            final isCredit = tx['type'] == 'credit';
            final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
            final formattedDate = DateFormat('MMM d, h:mm a').format(date);

            return Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        isCredit
                            ? AppColors.incomeBackground
                            : AppColors.expenseBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                    color: isCredit ? AppColors.income : AppColors.expense,
                  ),
                ),
                title: Text(
                  tx['patternName'] ?? tx['sender'] ?? "Unknown",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['categoryName'] ?? 'Uncategorized'),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  "${tx['amount']}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isCredit ? AppColors.income : AppColors.expense,
                  ),
                ),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => TransactionDetailScreen(transaction: tx),
                    ),
                  );

                  // Handle Instant Updates using the result logic we added earlier
                  if (result != null && mounted) {
                    // If update/delete occurred, refresh everything.
                    // Because standard fetch is fast enough, we can just trigger a refresh.
                    _viewModel.refreshAll();
                  }
                },
              ),
            );
          },
        ),
        if (doLimit && txs.length > limit)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _showAllTransactions = true;
                });
              },
              child: const Text("Show All"),
            ),
          ),
      ],
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Sort Transactions",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text("Date: Newest First"),
                trailing:
                    _viewModel.sortOption == SortOption.dateDesc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  _viewModel.setSortOption(SortOption.dateDesc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Date: Oldest First"),
                trailing:
                    _viewModel.sortOption == SortOption.dateAsc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  _viewModel.setSortOption(SortOption.dateAsc);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text("Amount: High to Low"),
                trailing:
                    _viewModel.sortOption == SortOption.amountDesc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  _viewModel.setSortOption(SortOption.amountDesc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text("Amount: Low to High"),
                trailing:
                    _viewModel.sortOption == SortOption.amountAsc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  _viewModel.setSortOption(SortOption.amountAsc);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getSortButtonLabel(SortOption option) {
    switch (option) {
      case SortOption.dateDesc:
        return "Newest First";
      case SortOption.dateAsc:
        return "Oldest First";
      case SortOption.amountDesc:
        return "Amount: High-Low";
      case SortOption.amountAsc:
        return "Amount: Low-High";
    }
  }
}
