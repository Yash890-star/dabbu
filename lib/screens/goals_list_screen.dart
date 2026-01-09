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
    // Filter active goals
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
    widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body:
          (!_isLoading && _goals.isEmpty)
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flag_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "No goals yet",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Create a savings goal to start tracking.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _showAddGoalDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("Create Goal"),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: () async {
                  await _loadGoals();
                  widget.onRefresh();
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_goals.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            "${_goals.length} Active Goals",
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      BentoGrid(
                        children:
                            _goals.map((goal) => _buildGoalTile(goal)).toList(),
                      ),
                      const SizedBox(height: 80), // Fab spacing
                    ],
                  ),
                ),
              ),
      floatingActionButton:
          _goals.isNotEmpty
              ? FloatingActionButton(
                onPressed: _showAddGoalDialog,
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  Widget _buildGoalTile(Map<String, dynamic> goal) {
    final target = (goal['targetAmount'] as num).toDouble();
    final saved = (goal['savedAmount'] as num?)?.toDouble() ?? 0.0;
    final progress = (saved / target).clamp(0.0, 1.0);
    final color =
        goal['color'] != null
            ? Color(goal['color'])
            : AppColors.defaultGoalColor;
    final isCompleted = progress >= 1.0;

    return AppCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalHistoryScreen(goal: goal),
          ),
        );
        await _loadGoals();
        widget.onRefresh();
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.emoji_events : Icons.star,
                  size: 18,
                  color: color,
                ),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? AppColors.income : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            goal['name'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            "₹${NumberFormat.compact().format(saved)}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          Text(
            "of ₹${NumberFormat.compact().format(target)}",
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: isCompleted ? AppColors.income : color,
              backgroundColor: color.withValues(alpha: 0.1),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
