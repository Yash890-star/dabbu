import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late int _selectedCategoryId;
  late String _categoryName;
  List<Map<String, dynamic>> _allCategories = [];

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.transaction['categoryId'] ?? 1;
    _categoryName = widget.transaction['categoryName'] ?? "Uncategorized";
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    setState(() => _allCategories = cats);
  }

  Future<void> _updateCategory(int newCatId, String newCatName) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      {'categoryId': newCatId},
      where: 'id = ?',
      whereArgs: [widget.transaction['id']],
    );

    setState(() {
      _selectedCategoryId = newCatId;
      _categoryName = newCatName;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Category updated")));
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.blue),
                title: const Text("Create New Category"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateCategoryDialog();
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _allCategories.length,
                  itemBuilder: (ctx, i) {
                    final cat = _allCategories[i];
                    return ListTile(
                      title: Text(cat['name']),
                      trailing:
                          _selectedCategoryId == cat['id']
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                      onTap: () {
                        _updateCategory(cat['id'], cat['name']);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showCreateCategoryDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("New Category"),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "e.g. Utilities"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (controller.text.isNotEmpty) {
                    int newId = await DatabaseHelper.instance.addCategory(
                      controller.text,
                    );
                    await _loadCategories(); // Refresh local list
                    await _updateCategory(
                      newId,
                      controller.text,
                    ); // Assign immediately
                    if (mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text("Create & Assign"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      widget.transaction['date'],
    );
    final isCredit = widget.transaction['type'] == 'credit';

    return Scaffold(
      appBar: AppBar(title: const Text("Details")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount & Icon
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        isCredit ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isCredit ? Colors.green : Colors.red,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${widget.transaction['amount']}",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat.yMMMMEEEEd().add_jm().format(date),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 40),

            // Details
            _detailRow("Sender", widget.transaction['sender']),
            const SizedBox(height: 20),

            // Category Row (Clickable)
            InkWell(
              onTap: _showCategoryPicker,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Category",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Chip(
                        label: Text(_categoryName),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "Original Message",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.transaction['body'] ?? ""),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
