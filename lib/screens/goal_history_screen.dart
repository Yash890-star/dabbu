import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../viewmodels/goal_history_view_model.dart';
import 'add_transaction_screen.dart';
import '../widgets/goals/goal_hero_card.dart';
import '../widgets/goals/history_timeline.dart';

class GoalHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> goal;
  const GoalHistoryScreen({super.key, required this.goal});

  @override
  State<GoalHistoryScreen> createState() => _GoalHistoryScreenState();
}

class _GoalHistoryScreenState extends State<GoalHistoryScreen> {
  final GoalHistoryViewModel _viewModel = GoalHistoryViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init(widget.goal);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _toggleArchive() async {
    final newStatus =
        await _viewModel.toggleArchive(); // returns true if archived
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? CMS.goals['goal_archived']!
                : CMS.goals['goal_unarchived']!,
          ),
        ),
      );
      Navigator.pop(context); // Return to previous screen (Home)
    }
  }

  Future<void> _deleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(CMS.goals['delete_goal_title']!),
            content: Text(CMS.goals['delete_goal_content']!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(CMS.common['cancel']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  CMS.common['delete']!,
                  style: const TextStyle(color: AppColors.expense),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _viewModel.deleteGoal();
      if (mounted) Navigator.pop(context, true); // Return true to refresh
    }
  }

  Future<void> _handleTransactionTap(Map<String, dynamic> tx) async {
    final success = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: tx),
      ),
    );

    if (success == true && mounted) {
      _viewModel.refresh();
    }
  }

  Future<void> _confirmLinkTransaction(Map<String, dynamic> tx) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(CMS.goals['select_impact_title']!),
            content: Text(
              (CMS.goals['select_impact_content'] as String).replaceFirst(
                '{goalName}',
                _viewModel.goal['name'],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _viewModel.linkTransactionToGoal(tx, false); // Subtract
                  _showLinkSuccess();
                },
                child: Text(
                  CMS.goals['subtract_action']!,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _viewModel.linkTransactionToGoal(tx, true); // Add
                  _showLinkSuccess();
                },
                child: Text(CMS.goals['add_action']!),
              ),
            ],
          ),
    );
  }

  void _showLinkSuccess() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (CMS.goals['transaction_linked'] as String).replaceFirst(
              '{goalName}',
              _viewModel.goal['name'],
            ),
          ),
        ),
      );
    }
  }

  void _showLinkTransactionPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder:
                (sheetContext, scrollController) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        (CMS.goals['link_transaction_title'] as String)
                            .replaceFirst(
                              '{goalName}',
                              _viewModel.goal['name'],
                            ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _viewModel.fetchUnlinkedTransactions(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final candidates = snapshot.data!;
                          if (candidates.isEmpty) {
                            return Center(
                              child: Text(
                                CMS.goals['no_unlinked_transactions']!,
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: candidates.length,
                            itemBuilder: (context, index) {
                              final tx = candidates[index];
                              final isCredit = tx['type'] == 'credit';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      isCredit
                                          ? AppColors.incomeBackground
                                          : AppColors.expenseBackground,
                                  child: Icon(
                                    isCredit
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color:
                                        isCredit
                                            ? AppColors.income
                                            : AppColors.expense,
                                    size: 16,
                                  ),
                                ),
                                title: Text(tx['sender'] ?? "Manual"),
                                subtitle: Text(
                                  "${DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(tx['date']))} • ${tx['categoryName']}",
                                ),
                                trailing: Text(
                                  "₹${tx['amount']}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onTap: () async {
                                  Navigator.pop(sheetContext); // Close picker
                                  _confirmLinkTransaction(tx);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showAddFundsOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                CMS.goals['add_funds_title']!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.incomeBackground,
                  child: const Icon(Icons.add, color: AppColors.income),
                ),
                title: Text(CMS.goals['new_deposit_title']!),
                subtitle: Text(CMS.goals['new_deposit_subtitle']!),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (!mounted) return;
                  final success = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddTransactionScreen(
                            initialGoalId: _viewModel.goal['id'],
                          ),
                    ),
                  );
                  if (success == true) _viewModel.refresh();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.link,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(CMS.goals['link_existing_title']!),
                subtitle: Text(CMS.goals['link_existing_subtitle']!),
                onTap: () {
                  Navigator.pop(context);
                  _showLinkTransactionPicker();
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
        final totalSaved = _viewModel.totalSaved;
        final goalTarget = (_viewModel.goal['targetAmount'] as num).toDouble();
        final progress = _viewModel.progress;
        final color = Color(
          _viewModel.goal['color'] ?? AppColors.defaultGoalColor.toARGB32(),
        );

        String motivation = "";
        if (progress >= 1) {
          motivation = CMS.goals['motivation_complete']!;
        } else if (progress >= 0.8) {
          motivation = CMS.goals['motivation_almost']!;
        } else if (progress >= 0.5) {
          motivation = CMS.goals['motivation_halfway']!;
        } else if (progress >= 0.2) {
          motivation = CMS.goals['motivation_started']!;
        } else {
          motivation = CMS.goals['motivation_beginning']!;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_viewModel.goal['name']),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'archive') _toggleArchive();
                  if (value == 'delete') _deleteGoal();
                },
                itemBuilder: (BuildContext context) {
                  final isArchived = (_viewModel.goal['isArchived'] ?? 0) == 1;
                  return [
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          Icon(
                            isArchived ? Icons.unarchive : Icons.archive,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isArchived
                                ? CMS.goals['unarchive_action']!
                                : CMS.goals['archive_action']!,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(
                            CMS.common['delete']!,
                            style: const TextStyle(color: AppColors.expense),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: Text(CMS.goals['add_funds_title']!),
            backgroundColor: color,
            onPressed: _showAddFundsOptions,
          ),
          body: RefreshIndicator(
            onRefresh: _viewModel.refresh,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GoalHeroCard(
                    goal: _viewModel.goal,
                    totalSaved: totalSaved,
                    progress: progress,
                    motivation: motivation,
                  ),

                  const SizedBox(height: 32),

                  if (_viewModel.transactions.isNotEmpty) ...[
                    Text(
                      "History",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    HistoryTimeline(
                      transactions: _viewModel.transactions,
                      onTap: _handleTransactionTap,
                    ),
                  ] else ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: Theme.of(context).dividerColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            CMS.goals['no_history']!,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
}
