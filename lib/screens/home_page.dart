import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';
import 'settings_page.dart';
import 'goals_list_screen.dart';
import '../viewmodels/home_view_model.dart';
import '../utils/app_colors.dart';
import '../widgets/home/welcome_block.dart';
import '../widgets/home/budget_gauge_block.dart';
import '../widgets/home/stat_card.dart';
import '../widgets/home/action_strip.dart';
import '../widgets/home/recent_transactions_block.dart';
import '../widgets/home/sublimit_block.dart';
import '../widgets/add_goal_dialog.dart';
import 'all_transactions_screen.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/fade_in_entry.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final HomeViewModel _viewModel = HomeViewModel();

  @override
  bool get wantKeepAlive => true;

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

  Future<void> _syncMessages() async {
    final int newCount = await _viewModel.syncMessages();

    if (mounted) {
      // final theme = Theme.of(context); // Unused
      // final isDark = theme.brightness == Brightness.dark; // Unused

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newCount > 0
                ? (CMS.home['new_transaction_found'] as String).replaceFirst(
                  '{count}',
                  '$newCount',
                )
                : CMS.home['no_new_transaction']!,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.black87, // High contrast for visibility
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_card,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_fix_high,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
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
    super.build(context);
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        final income =
            (_viewModel.summaryData['income'] as num?)?.toDouble() ?? 0.0;
        final expense =
            (_viewModel.summaryData['expense'] as num?)?.toDouble() ?? 0.0;
        // Using cardTheme color for StatCard background, or a specific fallback
        final statCardBg =
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface;

        return Scaffold(
          body: SafeArea(
            bottom:
                false, // Let navigation bar handle bottom padding if needed, or add manual padding
            child: RefreshIndicator(
              onRefresh: _syncMessages,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- 1. Header (Welcome) ---
                    WelcomeBlock(
                      userName: _viewModel.userName,
                      notificationCount: 0,
                      onNotificationTap: () {},
                      onScanSms: _syncMessages, // Wiring up scan SMS here
                    ),

                    // Month Selector
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _viewModel.changeSummaryMonth(-1),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              DateFormat(
                                'MMMM yyyy',
                              ).format(_viewModel.summaryMonth),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed:
                                _viewModel.canGoNext
                                    ? () => _viewModel.changeSummaryMonth(1)
                                    : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- 2. Financial Health (Budget Gauge) ---
                    // --- 2. Financial Health (Budget Gauge) ---
                    _viewModel.isLoading
                        ? const ShimmerLoading(
                          width: double.infinity,
                          height: 220,
                        )
                        : FadeInEntry(
                          delay: 200,
                          child: GestureDetector(
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity! > 0) {
                                // Swipe Right -> Previous Month
                                _viewModel.changeSummaryMonth(-1);
                              } else if (details.primaryVelocity! < 0) {
                                // Swipe Left -> Next Month
                                if (_viewModel.canGoNext) {
                                  _viewModel.changeSummaryMonth(1);
                                }
                              }
                            },
                            child: BudgetGaugeBlock(
                              totalBudget: _viewModel.monthlyBudget,
                              totalSpent: expense,
                              currencySymbol: CMS.common['currency_symbol']!,
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),

                    // --- 3. Quick Stats (Income / Expense) ---
                    // --- 3. Quick Stats (Income / Expense) ---
                    FadeInEntry(
                      delay: 300,
                      child: Row(
                        children: [
                          Expanded(
                            child:
                                _viewModel.isLoading
                                    ? const ShimmerLoading(
                                      width: double.infinity,
                                      height: 100,
                                    )
                                    : StatCard(
                                      title: CMS.home['credits_label']!,
                                      amount: NumberFormat.compactCurrency(
                                        symbol: CMS.common['currency_symbol']!,
                                      ).format(income),
                                      icon: Icons.arrow_downward,
                                      color: AppColors.income,
                                      backgroundColor: statCardBg,
                                    ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child:
                                _viewModel.isLoading
                                    ? const ShimmerLoading(
                                      width: double.infinity,
                                      height: 100,
                                    )
                                    : StatCard(
                                      title: CMS.home['spends_label']!,
                                      amount: NumberFormat.compactCurrency(
                                        symbol: CMS.common['currency_symbol']!,
                                      ).format(expense),
                                      icon: Icons.arrow_upward,
                                      color: AppColors.expense,
                                      backgroundColor: statCardBg,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- 4. Actions ---
                    // --- 4. Actions ---
                    FadeInEntry(
                      delay: 400,
                      child: ActionStrip(
                        onAddTransaction: () => _showAddMenu(context),
                        // onScanSms: _syncMessages, // Removed from here
                        onManageGoals: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => GoalsListScreen(
                                    goals: _viewModel.goals,
                                    onRefresh: _viewModel.refreshData,
                                  ),
                            ),
                          ).then((_) => _viewModel.refreshData());
                        },
                        onAddGoal: () async {
                          // Quick add goal popup without redirect
                          await showDialog(
                            context: context,
                            builder:
                                (context) => AddGoalDialog(
                                  onGoalAdded: _viewModel.refreshData,
                                ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- 4.5 Sublimits ---
                    // --- 4.5 Sublimits ---
                    _viewModel.isLoading
                        ? const ShimmerLoading(
                          width: double.infinity,
                          height: 150,
                        )
                        : FadeInEntry(
                          delay: 500,
                          child: SublimitBlock(
                            categories: _viewModel.categories,
                            categorySpending: _viewModel.categorySpending,
                            currencySymbol: CMS.common['currency_symbol']!,
                          ),
                        ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),

                    // --- 5. Recent Transactions ---
                    // --- 5. Recent Transactions ---
                    _viewModel.isLoading
                        ? const ShimmerLoading(
                          width: double.infinity,
                          height: 300,
                        )
                        : FadeInEntry(
                          delay: 600,
                          child: RecentTransactionsBlock(
                            transactions: _viewModel.transactions,
                            onViewAll: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => AllTransactionsScreen(
                                        transactions: _viewModel.transactions,
                                      ),
                                ),
                              );
                            },
                            onTransactionTap: (tx) async {
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
                          ),
                        ),

                    const SizedBox(height: 80), // Bottom padding for FAB/Nav
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
