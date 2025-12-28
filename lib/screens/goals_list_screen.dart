import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../widgets/bento_grid.dart';
import '../widgets/app_card.dart';
import 'goal_history_screen.dart';
import '../services/database_helper.dart';

import '../widgets/add_goal_dialog.dart';

class GoalsListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final VoidCallback onRefresh;

  const GoalsListScreen({
    super.key,
    required this.goals,
    required this.onRefresh,
    this.initialShowAdd = false,
  });

  final bool initialShowAdd;

  @override
  Widget build(BuildContext context) {
    // Basic implementation: If initialShowAdd is true, we should probably
    // trigger the add dialog. Since we are in build, we need a post-frame callback
    // or convert to StatefulWidget. For simplicity now, let's convert to StatefulWidget.
    // However, since I cannot easily refactor to Stateful in one go without errors,
    // I will ignore the parameter logic for now or rely on the user tapping the FAB/Action
    // which effectively opens this screen.
    // Wait, the user request implied "Add Goal Button" works.
    // Let's implement `add_goal_screen.dart` logic LATER if needed.
    // For now, I'll just accept the parameter to fix the build error.

    // Better yet, let's convert this to StatefulWidget to handle the auto-open.
    return _GoalsListScreenContent(
      goals: goals,
      onRefresh: onRefresh,
      initialShowAdd: initialShowAdd,
    );
  }
}

class _GoalsListScreenContent extends StatefulWidget {
  final List<Map<String, dynamic>> goals;
  final VoidCallback onRefresh;
  final bool initialShowAdd;

  const _GoalsListScreenContent({
    required this.goals,
    required this.onRefresh,
    required this.initialShowAdd,
  });

  @override
  State<_GoalsListScreenContent> createState() =>
      _GoalsListScreenContentState();
}

class _GoalsListScreenContentState extends State<_GoalsListScreenContent> {
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
    if (widget.initialShowAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddGoalDialog();
      });
    }
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    final allGoals = await DatabaseHelper.instance.getAllGoals();
    // Filter out archived goals if needed, or the helper does it?
    // The helper likely returns ALL, usually explicitly filtered.
    // Based on HomeViewModel, it gets ALL. Usually active goals are shown here.
    // Let's assume we want only active ones for the "List".
    // Checking HomeViewModel logic: it uses 'allGoals'.
    // Wait, the UI in Home checks active? No, looks like it shows all in BentoGrid?
    // Let's check 'database_helper.dart' for 'getAllGoals'.
    // Actually, usually Main List shows Active. Archived are in Settings.
    // I'll filter by 'isArchived != 1'.

    final active = allGoals.where((g) => (g['isArchived'] ?? 0) == 0).toList();

    if (mounted) {
      setState(() {
        _goals = active;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddGoalDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AddGoalDialog(onGoalAdded: _loadGoals),
    );
    widget.onRefresh(); // Keep notifying parent just in case
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Savings Goals"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddGoalDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadGoals();
          widget.onRefresh();
        },
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _goals.isEmpty
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        "No goals yet",
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
                : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: BentoGrid(
                    crossAxisCount: 2,
                    children:
                        _goals.map((goal) {
                          final target =
                              (goal['targetAmount'] as num).toDouble();
                          final saved =
                              (goal['savedAmount'] as num?)?.toDouble() ?? 0.0;
                          final progress = (saved / target).clamp(0.0, 1.0);
                          final color =
                              goal['color'] != null
                                  ? Color(goal['color'])
                                  : AppColors.defaultGoalColor;

                          return AppCard(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          GoalHistoryScreen(goal: goal),
                                ),
                              );
                              await _loadGoals(); // Refresh local list
                              widget.onRefresh(); // Refresh parent
                            },
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: color.withValues(
                                        alpha: 0.2,
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        size: 14,
                                        color: color,
                                      ),
                                    ),
                                    Text(
                                      "${(progress * 100).toStringAsFixed(0)}%",
                                      style: TextStyle(
                                        fontSize: 12,
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
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                LinearProgressIndicator(
                                  value: progress,
                                  color: color,
                                  backgroundColor: color.withValues(alpha: 0.1),
                                  minHeight: 4,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${NumberFormat.compact().format(saved)} / ${NumberFormat.compact().format(target)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
      ),
    );
  }
}
