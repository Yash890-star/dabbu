import 'package:flutter/material.dart';
import '../services/database_helper.dart';

import 'package:another_telephony/telephony.dart';
import 'sms_parsing_screen.dart';
import 'sms_setup_screen.dart'; // To add new regex

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final pats = await db.database.then((d) => d.query('patterns'));
    final cats = await db.getCategories();

    if (mounted) {
      setState(() {
        _patterns = pats;
        _categories = cats;
      });
    }
  }

  // --- Category Logic ---
  Future<void> _addOrEditCategory() async {
    final controller = TextEditingController();
    Color selectedColor = _categoryColors[0]; // Default to Red

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            // StatefulBuilder allows updating the dialog UI (the color selection)
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("New Category"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: "Category Name",
                        border: OutlineInputBorder(),
                        hintText: "e.g. Travel",
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Pick a Color:",
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
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.trim().isEmpty) return;

                      await DatabaseHelper.instance.addCategory(
                        controller.text.trim(),
                        color: selectedColor.value, // Save the color integer
                      );

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadData();
                      }
                    },
                    child: const Text("Save"),
                  ),
                ],
              );
            },
          ),
    );
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
                    child: const Text("OK"),
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
        title: const Text("Settings"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: "Patterns"), Tab(text: "Categories")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
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
                title: const Text("Add New Regex Pattern"),
                subtitle: const Text("Scan SMS to train a new bank format"),
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
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "No patterns saved.",
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

          // 2. Categories Tab
          Scaffold(
            // Nested scaffold for FAB
            floatingActionButton: FloatingActionButton(
              onPressed: () => _addOrEditCategory(),
              child: const Icon(Icons.add),
            ),
            body: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Text(cat['name'][0].toUpperCase()),
                  ),
                  title: Text(cat['name']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
