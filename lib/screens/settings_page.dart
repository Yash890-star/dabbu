import 'package:flutter/material.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../utils/theme_controller.dart';
import '../services/notification_service.dart'; // Import Service

import 'sms_parsing_screen.dart';
import 'notification_settings_screen.dart'; // Import Screen
import 'sms_setup_screen.dart';
import 'category_rule_setup_screen.dart';
import 'subscriptions_screen.dart';
import '../viewmodels/settings_view_model.dart';
import '../widgets/settings/settings_section.dart';

class SettingsPage extends StatefulWidget {
  final int initialIndex;
  const SettingsPage({super.key, this.initialIndex = 0});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin {
  final SettingsViewModel _viewModel = SettingsViewModel();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _viewModel.loadData();
  }

  void refresh() {
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> openBudgetEditDialog() async {
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
      builder: (ctx) {
        // Local state for rules - MOVED OUTSIDE StatefulBuilder
        List<Map<String, dynamic>> rules = [];
        bool isLoadingRules = true;
        bool hasStartedLoading = false;

        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            // Helper to load rules
            Future<void> loadRules() async {
              if (existingCategory == null) {
                if (innerContext.mounted) {
                  setDialogState(() {
                    isLoadingRules = false;
                  });
                }
                return;
              }
              try {
                final r = await _viewModel.getCategoryRules(
                  existingCategory['id'],
                );
                if (innerContext.mounted) {
                  setDialogState(() {
                    rules = r;
                    isLoadingRules = false;
                  });
                }
              } catch (e) {
                debugPrint("Error loading rules: $e");
                if (innerContext.mounted) {
                  setDialogState(() {
                    rules = [];
                    isLoadingRules = false;
                  });
                }
              }
            }

            // Load once
            if (!hasStartedLoading) {
              hasStartedLoading = true;
              loadRules();
            }

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
                                                  innerContext,
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
                    const SizedBox(height: 24),
                    if (existingCategory != null) ...[
                      const Divider(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Auto-Categorization Rules",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isLoadingRules)
                        const Center(
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (!isLoadingRules && rules.isEmpty)
                        const Text(
                          "No keywords set.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      if (!isLoadingRules && rules.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          children:
                              rules
                                  .map(
                                    (r) => Chip(
                                      label: Text(r['keyword']),
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 16,
                                      ),
                                      onDeleted: () async {
                                        await _viewModel.deleteCategoryRule(
                                          r['id'],
                                        );
                                        loadRules(); // Refresh
                                      },
                                    ),
                                  )
                                  .toList(),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add Keyword Rule"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CategoryRuleSetupScreen(
                                    categoryId: existingCategory['id'],
                                    categoryName: existingCategory['name'],
                                  ),
                            ),
                          ).then((val) {
                            if (val == true) {
                              loadRules();
                            }
                          });
                        },
                      ),
                    ],
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
                    if (mounted && wasBudgetUpdated) {
                      ScaffoldMessenger.of(context).showSnackBar(
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
        );
      },
    );
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
    final nameController = TextEditingController(text: pattern['name']);
    bool isLiquid = (pattern['isLiquid'] as int? ?? 1) == 1;

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  CMS.settings['edit_pattern_title'] ?? 'Edit Pattern',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText:
                            CMS.smsParsing['pattern_name_label'] ?? 'Name',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text("Affects Bank Balance"),
                      subtitle: const Text("Include in Tally calculations"),
                      value: isLiquid,
                      onChanged: (val) {
                        setDialogState(() {
                          isLiquid = val;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.build),
                      label: const Text("Edit Extraction Logic"),
                      onPressed: () async {
                        // Navigate to logic editor
                        final sms = await _viewModel.findLatestSms(
                          pattern['senderId'],
                        );
                        if (sms != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SmsParsingScreen(
                                    message: sms,
                                    existingPatternId: pattern['id'],
                                    initialPatternName: nameController.text,
                                  ),
                            ),
                          ).then((_) {
                            // Refresh parent? Logic editor saves directly.
                            Navigator.pop(ctx);
                            _viewModel.loadData();
                          });
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("No SMS found to edit logic"),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(CMS.common['cancel']!),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await _viewModel.updatePattern(
                        pattern['id'],
                        nameController.text,
                        isLiquid,
                      );
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: Text(CMS.common['save']!),
                  ),
                ],
              );
            },
          ),
    );
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
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(CMS.settings['app_bar_title']!),
        centerTitle: false,
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. GENERAL SETTINGS
                SettingsSection(
                  title: CMS.settings['general_settings_header']!,
                  icon: Icons.tune,
                  children: [
                    // Theme Switcher
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController(),
                      builder: (context, mode, child) {
                        final isDark =
                            mode == ThemeMode.dark ||
                            (mode == ThemeMode.system &&
                                MediaQuery.of(context).platformBrightness ==
                                    Brightness.dark);
                        return SwitchListTile(
                          secondary: Icon(
                            isDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            color: isDark ? Colors.purpleAccent : Colors.orange,
                          ),
                          title: Text(isDark ? "Dark Mode" : "Light Mode"),
                          value: isDark,
                          onChanged: (val) {
                            ThemeController().toggleTheme(val);
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.walletIcon,
                      ),
                      title: Text(CMS.settings['monthly_budget']!),
                      subtitle: Text(
                        _viewModel.monthlyBudget > 0
                            ? "₹ ${_viewModel.monthlyBudget.toStringAsFixed(0)}"
                            : CMS.settings['monthly_budget_not_set']!,
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: openBudgetEditDialog,
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.deepPurple,
                      ),
                      title: const Text("Notifications"),
                      subtitle: const Text("Reminders & Alerts"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.receipt_long_outlined,
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
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                        Icons.archive_outlined,
                        color: AppColors.archiveIcon,
                      ),
                      title: Text(CMS.settings['archived_goals_title']!),
                      subtitle: Text(CMS.settings['archived_goals_subtitle']!),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _showArchivedGoals,
                    ),
                  ],
                ),

                // 2. CATEGORIES
                SettingsSection(
                  title: CMS.settings['categories_header']!,
                  icon: Icons.category_outlined,
                  children: [
                    ..._viewModel.categories.map((cat) {
                      final budget =
                          cat['budgetLimit'] != null && cat['budgetLimit'] > 0
                              ? "${CMS.settings['budget_prefix']!}₹${cat['budgetLimit']}"
                              : CMS.settings['no_limit']!;
                      final color =
                          cat['color'] != null
                              ? Color(cat['color'])
                              : Theme.of(context).disabledColor;

                      return Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.2),
                              child: Icon(Icons.circle, color: color, size: 12),
                            ),
                            title: Text(
                              cat['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(budget),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (cat['budgetLimit'] != null &&
                                    (cat['budgetLimit'] as num) > 0)
                                  IconButton(
                                    tooltip:
                                        CMS.settings['reset_limit_tooltip']!,
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
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => _addOrEditCategory(cat),
                                ),
                              ],
                            ),
                            onTap: () => _addOrEditCategory(cat),
                          ),
                          const Divider(height: 1, indent: 56),
                        ],
                      );
                    }),
                    ListTile(
                      leading: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue,
                      ),
                      title: Text(
                        CMS.settings['add_category']!,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _addOrEditCategory(),
                    ),
                  ],
                ),

                // 3. PATTERNS
                SettingsSection(
                  title: CMS.settings['patterns_tab']!,
                  icon: Icons.code,
                  children: [
                    ..._viewModel.patterns.map(
                      (p) => Column(
                        children: [
                          ListTile(
                            title: Text(
                              p['name'] ?? "Unnamed",
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              p['senderId'],
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => _editPattern(p),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppColors.delete,
                                  ),
                                  onPressed: () => _deletePattern(p['id']),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 16),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.add, color: Colors.blue),
                      title: Text(
                        CMS.settings['add_pattern_title']!,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SmsSetupScreen(),
                          ),
                        ).then((_) => _viewModel.loadData());
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
