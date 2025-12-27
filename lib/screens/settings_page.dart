import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/cms.dart';

import 'package:another_telephony/telephony.dart';
import 'sms_parsing_screen.dart';
import 'sms_setup_screen.dart'; // To add new regex
import 'subscriptions_screen.dart';

class SettingsPage extends StatefulWidget {
  final int initialIndex;
  const SettingsPage({super.key, this.initialIndex = 0});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final List<Color> _categoryColors = [
  Colors.red,
  Colors.pink,
  Colors.purple,
  Colors.deepPurple,
  Colors.indigo,
  Colors.blue,
  Colors.lightBlue,
  Colors.cyan,
  Colors.teal,
  Colors.green,
  Colors.lightGreen,
  Colors.lime,
  Colors.yellow,
  Colors.amber,
  Colors.orange,
  Colors.deepOrange,
  Colors.brown,
  Colors.grey,
  Colors.blueGrey,
  Colors.black,
];

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _patterns = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _goals = []; // Added goals

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _loadData();
  }

  double _monthlyBudget = 0.0;

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final pats = await db.database.then((d) => d.query('patterns'));
    final cats = await db.getCategories();
    final goalsList = await db.getAllGoals(); // Fetch goals
    final prefs = await SharedPreferences.getInstance();
    final budget = prefs.getDouble('monthly_budget') ?? 0.0;

    if (mounted) {
      setState(() {
        _patterns = pats;
        _categories = cats;
        _goals = goalsList;
        _monthlyBudget = budget;
      });
    }
  }

  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text: _monthlyBudget > 0 ? _monthlyBudget.toStringAsFixed(0) : "",
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
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final val = double.tryParse(controller.text) ?? 0.0;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('monthly_budget', val);
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
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
            : _categoryColors[0]; // Default to Red

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  existingCategory == null ? "New Category" : "Edit Category",
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
                            _categoryColors.map((color) {
                              final isSelected =
                                  selectedColor.value == color.value;
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
                                              color: Colors.black,
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
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) return;

                      final budget =
                          double.tryParse(budgetController.text) ?? 0.0;

                      if (existingCategory == null) {
                        await DatabaseHelper.instance.addCategory(
                          nameController.text.trim(),
                          color: selectedColor.value,
                          budget: budget,
                        );
                      } else {
                        await DatabaseHelper.instance.updateCategory({
                          'id': existingCategory['id'],
                          'name': nameController.text.trim(),
                          'color': selectedColor.value,
                          'budgetLimit': budget,
                          'icon': existingCategory['icon'], // Preserve icon
                        });
                      }

                      // --- New Logic: Auto-update Monthly Budget ---
                      if (budget > 0) {
                        double totalCategoryBudget = 0.0;
                        final allCats =
                            await DatabaseHelper.instance.getCategories();
                        for (var c in allCats) {
                          totalCategoryBudget +=
                              (c['budgetLimit'] as num? ?? 0.0).toDouble();
                        }

                        // If the sum exceeds global budget (or global is 0), update it
                        if (totalCategoryBudget > _monthlyBudget) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setDouble(
                            'monthly_budget',
                            totalCategoryBudget,
                          );

                          // Show info dialog
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Monthly Budget updated to ₹${totalCategoryBudget.toStringAsFixed(0)} to match category limits.",
                                ),
                                backgroundColor: Colors.blue,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      }
                      // ---------------------------------------------

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadData(); // Re-load to show updated global budget
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
        const SnackBar(
          content: Text("Cannot delete the default 'Uncategorized' category."),
        ),
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
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(CMS.common['delete']!),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteCategory(id);
      _loadData(); // Refresh UI
    }
  }

  // --- Pattern Logic ---
  Future<void> _editPattern(Map<String, dynamic> pattern) async {
    // 1. Fetch latest SMS for this sender
    final senderId = pattern['senderId'];
    final Telephony telephony = Telephony.instance;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS).like("%$senderId%"),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading

      if (messages.isNotEmpty) {
        // 2. Open Visual Editor with the latest message
        final sms = messages.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => SmsParsingScreen(
                  message: sms,
                  existingPatternId: pattern['id'],
                  initialPatternName: pattern['name'],
                  // We'd ideally pass the category ID here, but for now user can re-select if needed
                ),
          ),
        ).then((_) => _loadData()); // Refresh after return
      } else {
        // No SMS found
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text("No SMS Found"),
                content: Text(
                  "Could not find any recent SMS from $senderId to retrain the pattern.",
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
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading if error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error finding SMS: $e")));
    }
  }

  void _showArchivedGoals() {
    final archived = _goals.where((g) => (g['isArchived'] ?? 0) == 1).toList();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Archived Goals"),
            content:
                archived.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No archived goals."),
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
                              color: Color(goal['color'] ?? Colors.grey.value),
                            ),
                            title: Text(goal['name']),
                            subtitle: Text("Target: ₹${goal['targetAmount']}"),
                            trailing: TextButton(
                              child: const Text("Restore"),
                              onPressed: () async {
                                await DatabaseHelper.instance.archiveGoal(
                                  goal['id'],
                                  false,
                                );
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  _loadData();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "'${goal['name']}' restored to Home Screen",
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
                child: const Text("Close"),
              ),
            ],
          ),
    );
  }

  Future<void> _deletePattern(int id) async {
    // Show confirmation dialog
    final shouldDeleteTransactions = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Delete Pattern?"),
            content: const Text(
              "Do you want to delete the transactions associated with this pattern as well?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null), // Cancel
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // Keep Transactions
                child: const Text("Keep Transactions"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true), // Delete All
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete All"),
              ),
            ],
          ),
    );

    // If cancelled (null), do nothing
    if (shouldDeleteTransactions == null) return;

    // Proceed with deletion
    await DatabaseHelper.instance.deletePattern(
      id,
      deleteTransactions: shouldDeleteTransactions,
    );
    _loadData();
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
      body: TabBarView(
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
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.deepPurple,
                ),
                title: Text(CMS.settings['monthly_budget']!),
                subtitle: Text(
                  _monthlyBudget > 0
                      ? "₹ ${_monthlyBudget.toStringAsFixed(0)}"
                      : CMS.settings['monthly_budget_not_set']!,
                ),
                trailing: const Icon(Icons.edit),
                onTap: _editBudget,
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.purple),
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
                leading: const Icon(Icons.archive, color: Colors.orange),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue,
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

              if (_categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(CMS.settings['no_categories']!),
                ),

              ..._categories.map((cat) {
                final budget =
                    cat['budgetLimit'] != null && cat['budgetLimit'] > 0
                        ? "${CMS.settings['budget_prefix']!}₹${cat['budgetLimit']}"
                        : CMS.settings['no_limit']!;
                final color =
                    cat['color'] != null ? Color(cat['color']) : Colors.grey;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
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
                            // Update limit to 0
                            await DatabaseHelper.instance.updateCategory({
                              ...cat, // Keep other fields
                              'budgetLimit': 0.0,
                            });
                            _loadData();
                          },
                        ),

                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.blue,
                        ),
                        onPressed: () => _addOrEditCategory(cat),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          size: 20,
                          color: Colors.red,
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.blue),
                ),
                title: Text(CMS.settings['add_pattern_title']!),
                subtitle: Text(CMS.settings['add_pattern_subtitle']!),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SmsSetupScreen(),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              const Divider(),
              if (_patterns.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    CMS.settings['no_patterns']!,
                    textAlign: TextAlign.center,
                  ),
                ),

              ..._patterns.map(
                (p) => ListTile(
                  title: Text(p['name'] ?? "Unnamed"),
                  subtitle: Text(p['senderId']),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editPattern(p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePattern(p['id']),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
