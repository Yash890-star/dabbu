import 'package:flutter/material.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';

import 'sms_parsing_screen.dart';
import 'sms_setup_screen.dart';
import 'subscriptions_screen.dart';
import '../viewmodels/settings_view_model.dart';

class SettingsPage extends StatefulWidget {
  final int initialIndex;
  const SettingsPage({super.key, this.initialIndex = 0});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SettingsViewModel _viewModel = SettingsViewModel();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text:
          _viewModel.monthlyBudget > 0
              ? _viewModel.monthlyBudget.toStringAsFixed(0)
              : "",
    );

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.settings['edit_budget_dialog_title']!),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: CMS.settings['monthly_budget_subtitle']!,
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(CMS.common['cancel']!),
              ),
              ElevatedButton(
                onPressed: () async {
                  final val = double.tryParse(controller.text) ?? 0.0;
                  await _viewModel.setMonthlyBudget(val);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(CMS.common['save']!),
              ),
            ],
          ),
    );
  }

  // --- Category Logic ---
  Future<void> _addOrEditCategory([
    Map<String, dynamic>? existingCategory,
  ]) async {
    final nameController = TextEditingController(
      text: existingCategory?['name'] ?? '',
    );
    final budgetController = TextEditingController(
      text:
          existingCategory != null &&
                  existingCategory['budgetLimit'] != null &&
                  existingCategory['budgetLimit'] > 0
              ? existingCategory['budgetLimit'].toString()
              : '',
    );
    Color selectedColor =
        existingCategory != null && existingCategory['color'] != null
            ? Color(existingCategory['color'])
            : _viewModel.categoryColors[0]; // Default to Red

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  existingCategory == null
                      ? CMS.settings['new_category_title']!
                      : CMS.settings['edit_category_title']!,
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: CMS.settings['category_name_label']!,
                          border: const OutlineInputBorder(),
                          hintText: CMS.settings['category_name_hint']!,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: budgetController,
                        decoration: InputDecoration(
                          labelText: CMS.settings['category_limit_label']!,
                          border: const OutlineInputBorder(),
                          hintText: CMS.settings['category_limit_hint']!,
                          prefixText: "₹ ",
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CMS.settings['pick_color']!,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Color Picker Grid
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            _viewModel.categoryColors.map((color) {
                              final isSelected =
                                  selectedColor.toARGB32() == color.toARGB32();
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border:
                                        isSelected
                                            ? Border.all(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                              width: 3,
                                            )
                                            : null,
                                    boxShadow: [
                                      if (isSelected)
                                        const BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child:
                                      isSelected
                                          ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 20,
                                          )
                                          : null,
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(CMS.common['cancel']!),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) return;

                      final budget =
                          double.tryParse(budgetController.text) ?? 0.0;

                      final wasBudgetUpdated = await _viewModel
                          .addOrUpdateCategory(
                            id: existingCategory?['id'],
                            name: nameController.text.trim(),
                            colorValue: selectedColor.toARGB32(),
                            budgetLimit: budget,
                            icon: existingCategory?['icon'],
                          );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      // Use ctx (from showDialog context) or Ensure context is valid if using ScaffoldMessenger
                      if (ctx.mounted && wasBudgetUpdated) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(CMS.settings['auto_budget_update']!),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    child: Text(CMS.common['save']!),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _deleteCategory(int id) async {
    // 1. Prevent deleting Default Category
    if (id == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CMS.settings['cannot_delete_default']!)),
      );
      return;
    }

    // 2. Confirm Deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.settings['delete_category_title']!),
            content: Text(CMS.settings['delete_category_content']!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(CMS.common['cancel']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.delete),
                child: Text(CMS.common['delete']!),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _viewModel.deleteCategory(id);
    }
  }

  Future<void> _showArchivedGoals() async {
    final archived =
        _viewModel.goals.where((g) => (g['isArchived'] ?? 0) == 1).toList();

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.settings['archived_goals_title']!),
            content:
                archived.isEmpty
                    ? Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(CMS.settings['no_archived_goals']!),
                    )
                    : SizedBox(
                      width: double.maxFinite,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: archived.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (c, i) {
                          final goal = archived[i];
                          return ListTile(
                            leading: Icon(
                              Icons.archive,
                              color: Color(
                                goal['color'] ?? Colors.grey.toARGB32(),
                              ),
                            ),
                            title: Text(goal['name']),
                            subtitle: Text("Target: ₹${goal['targetAmount']}"),
                            trailing: TextButton(
                              child: Text(CMS.common['restore']!),
                              onPressed: () async {
                                await _viewModel.restoreGoal(goal['id']);
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        (CMS.settings['restored_msg'] as String)
                                            .replaceFirst(
                                              '{goalName}',
                                              goal['name'],
                                            ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(CMS.common['close']!),
              ),
            ],
          ),
    );
  }

  // --- Pattern Logic ---
  Future<void> _editPattern(Map<String, dynamic> pattern) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final sms = await _viewModel.findLatestSms(pattern['senderId']);

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading

    if (sms != null) {
      // Open Visual Editor with the latest message
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => SmsParsingScreen(
                message: sms,
                existingPatternId: pattern['id'],
                initialPatternName: pattern['name'],
              ),
        ),
      ).then((_) => _viewModel.loadData());
    } else {
      // No SMS found
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(CMS.settings['no_sms_title']!),
              content: Text(
                (CMS.errors['no_sms_found'] as String).replaceFirst(
                  '{senderId}',
                  pattern['senderId'],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(CMS.common['ok']!),
                ),
              ],
            ),
      );
    }
  }

  Future<void> _deletePattern(int id) async {
    // Show confirmation dialog
    final shouldDeleteTransactions = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.settings['delete_pattern_title']!),
            content: Text(CMS.settings['delete_pattern_content']!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null), // Cancel
                child: Text(CMS.common['cancel']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // Keep Transactions
                child: Text(CMS.settings['keep_transactions_btn']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true), // Delete All
                style: TextButton.styleFrom(foregroundColor: AppColors.delete),
                child: Text(CMS.settings['delete_all_btn']!),
              ),
            ],
          ),
    );

    if (shouldDeleteTransactions == null) return;

    await _viewModel.deletePattern(
      id,
      deleteTransactions: shouldDeleteTransactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(CMS.settings['app_bar_title']!),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: CMS.settings['general_tab']!),
            Tab(text: CMS.settings['patterns_tab']!),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // 0. General Tab (Now includes Categories)
              ListView(
                children: [
                  // Section 1: Budget
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      CMS.settings['general_settings_header']!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: AppColors.walletIcon,
                    ),
                    title: Text(CMS.settings['monthly_budget']!),
                    subtitle: Text(
                      _viewModel.monthlyBudget > 0
                          ? "₹ ${_viewModel.monthlyBudget.toStringAsFixed(0)}"
                          : CMS.settings['monthly_budget_not_set']!,
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: _editBudget,
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.receipt_long,
                      color: AppColors.subscriptionIcon,
                    ),
                    title: Text(CMS.settings['subscriptions_title']!),
                    subtitle: Text(CMS.settings['subscriptions_subtitle']!),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionsScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.archive,
                      color: AppColors.archiveIcon,
                    ),
                    title: Text(CMS.settings['archived_goals_title']!),
                    subtitle: Text(CMS.settings['archived_goals_subtitle']!),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _showArchivedGoals,
                  ),

                  const Divider(height: 32),
                  // Section 2: Categories
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CMS.settings['categories_header']!,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _addOrEditCategory(),
                          icon: const Icon(Icons.add_circle, size: 20),
                          label: Text(CMS.settings['add_category']!),
                        ),
                      ],
                    ),
                  ),

                  if (_viewModel.categories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(CMS.settings['no_categories']!),
                    ),

                  ..._viewModel.categories.map((cat) {
                    final budget =
                        cat['budgetLimit'] != null && cat['budgetLimit'] > 0
                            ? "${CMS.settings['budget_prefix']!}₹${cat['budgetLimit']}"
                            : CMS.settings['no_limit']!;
                    final color =
                        cat['color'] != null
                            ? Color(cat['color'])
                            : Theme.of(context).disabledColor;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Icon(Icons.category, color: color),
                      ),
                      title: Text(cat['name']),
                      subtitle: Text(budget),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Reset Limit Button (Only if limit > 0)
                          if (cat['budgetLimit'] != null &&
                              (cat['budgetLimit'] as num) > 0)
                            IconButton(
                              tooltip: CMS.settings['reset_limit_tooltip']!,
                              icon: const Icon(
                                Icons.restart_alt,
                                size: 20,
                                color: Colors.orange,
                              ),
                              onPressed: () async {
                                await _viewModel.addOrUpdateCategory(
                                  id: cat['id'],
                                  name: cat['name'],
                                  colorValue: cat['color'],
                                  budgetLimit: 0.0,
                                  icon: cat['icon'],
                                );
                              },
                            ),

                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () => _addOrEditCategory(cat),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: AppColors.delete,
                            ),
                            onPressed: () => _deleteCategory(cat['id']),
                          ),
                        ],
                      ),
                      onTap: () => _addOrEditCategory(cat),
                    );
                  }),

                  const SizedBox(height: 80), // Bottom padding
                ],
              ),

              // 1. Patterns Tab
              ListView(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(CMS.settings['add_pattern_title']!),
                    subtitle: Text(CMS.settings['add_pattern_subtitle']!),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SmsSetupScreen(),
                        ),
                      ).then((_) => _viewModel.loadData());
                    },
                  ),
                  const Divider(),
                  if (_viewModel.patterns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        CMS.settings['no_patterns']!,
                        textAlign: TextAlign.center,
                      ),
                    ),

                  ..._viewModel.patterns.map(
                    (p) => ListTile(
                      title: Text(p['name'] ?? "Unnamed"),
                      subtitle: Text(p['senderId']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () => _editPattern(p),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: AppColors.delete,
                            ),
                            onPressed: () => _deletePattern(p['id']),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
