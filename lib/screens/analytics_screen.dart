import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../viewmodels/analytics_view_model.dart';
import 'transaction_detail_screen.dart';
import '../widgets/bento_grid.dart';
import '../widgets/analytics/period_selector.dart';
import '../widgets/analytics/insight_block.dart';
import '../widgets/analytics/chart_block.dart';
import '../widgets/analytics/category_bento.dart';

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
          appBar: AppBar(
            title: Text(
              CMS.analytics['title']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Controls Row (Period + Type)
                  _buildControls(),
                  const SizedBox(height: 16),

                  // 2. Insight Block (2x1)
                  if (!_viewModel.isLoading &&
                      _viewModel.insights.isNotEmpty) ...[
                    _buildInsightBlock(),
                    const SizedBox(height: 16),
                  ],

                  // 3. Chart Block (2x2)
                  ChartBlock(
                    sections:
                        _viewModel.categorySummaries
                            .map(
                              (s) => ChartSectionData(
                                color: s.color,
                                value: s.amount,
                                percentage: s.percentage / 100,
                                title: s.name,
                              ),
                            )
                            .toList(),
                    totalAmount: displayedTotal,
                    isEmpty: !_viewModel.isLoading && displayedTotal == 0,
                    centerLabel:
                        "Total ${_viewModel.transactionType == 'debit' ? 'Spent' : 'Income'}",
                  ),
                  const SizedBox(height: 16),

                  // 4. Categories Grid (1x1 Bento)
                  if (_viewModel.categorySummaries.isNotEmpty) ...[
                    const Text(
                      "Top Categories",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    BentoGrid(
                      children:
                          _viewModel.categorySummaries.take(4).map((item) {
                            return CategoryBento(
                              categoryName: item.name,
                              amount: NumberFormat.compactCurrency(
                                symbol: '₹',
                              ).format(item.amount),
                              percentage: item.percentage / 100,
                              color: item.color,
                              icon:
                                  Icons
                                      .pie_chart, // Using generic as icons aren't in VM yet
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 5. Recent Transactions
                  if (_viewModel.transactions.isNotEmpty) ...[
                    Text(
                      CMS.analytics['recent_transactions']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _viewModel.transactions.length,
                      itemBuilder: (context, index) {
                        // Reusing existing logic manually or we could reuse RecentTransactionsBlock logic
                        // For now, implementing simple list item consistent with design
                        final tx = _viewModel.transactions[index];
                        final isCredit = tx['type'] == 'credit';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.1),
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
                                isCredit
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                size: 18,
                                color:
                                    isCredit
                                        ? AppColors.income
                                        : AppColors.expense,
                              ),
                            ),
                            title: Text(
                              tx['patternName'] ?? tx['sender'] ?? "Unknown",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              "${DateFormat.MMMd().format(DateTime.fromMillisecondsSinceEpoch(tx['date']))} • ${tx['categoryName'] ?? 'Uncategorized'}",
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Text(
                              "${tx['amount']}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color:
                                    isCredit
                                        ? AppColors.income
                                        : AppColors.expense,
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
                              if (context.mounted) {
                                _viewModel.refreshAll();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        PeriodSelector(
          selectedPeriod: _viewModel.timeFrame,
          periods: const ['Day', 'Week', 'Month'],
          onChanged: (val) => _viewModel.setTimeFrame(val),
        ),
        const SizedBox(height: 16),
        // Date Navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _viewModel.changeDate(-1),
                tooltip: "Previous",
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 100),
                alignment: Alignment.center,
                child: Text(
                  _viewModel.getDateLabel(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _viewModel.changeDate(1),
                tooltip: "Next",
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
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
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return _viewModel.transactionType == 'debit'
                    ? AppColors.expenseBackground
                    : AppColors.incomeBackground;
              }
              return null;
            }),
            foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return Theme.of(context).colorScheme.onSurface;
              }
              return Theme.of(context).colorScheme.onSurfaceVariant;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightBlock() {
    final insight = _viewModel.insights.first; // Main insight
    final isPositive = insight.percentageChange > 0;
    final isExpense = _viewModel.transactionType == 'debit';
    final isGood = isExpense ? !isPositive : isPositive;

    return InsightBlock(
      title: insight.categoryName,
      amount:
          "${isPositive ? '+' : ''}${insight.percentageChange.toStringAsFixed(0)}% vs last ${_viewModel.timeFrame.toLowerCase()}",
      subtitle:
          "${NumberFormat.compactCurrency(symbol: '₹').format(insight.diffAmount)} (${NumberFormat.compactCurrency(symbol: '₹').format(insight.currentAmount)})",
      isPositive: isPositive,
      isGood: isGood,
    );
  }
}
