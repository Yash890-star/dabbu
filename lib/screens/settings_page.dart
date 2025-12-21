import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'sms_setup_screen.dart'; // To add new regex

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

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
  Future<void> _addOrEditCategory({Map<String, dynamic>? existing}) async {
    final controller = TextEditingController(text: existing?['name']);

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(existing == null ? "New Category" : "Edit Category"),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "Category Name",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;

                  if (existing == null) {
                    await DatabaseHelper.instance.addCategory(
                      controller.text.trim(),
                    );
                  } else {
                    // For edit, we would need an update method in DB helper,
                    // for MVP let's stick to Add. (Or implement update if crucial)
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadData();
                  }
                },
                child: const Text("Save"),
              ),
            ],
          ),
    );
  }

  // --- Pattern Logic ---
  Future<void> _deletePattern(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('patterns', where: 'id = ?', whereArgs: [id]);
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
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deletePattern(p['id']),
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
