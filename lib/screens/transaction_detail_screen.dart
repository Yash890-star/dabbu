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

  // Edit Mode State
  bool _isManual = false;
  bool _isEditing = false;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.transaction['categoryId'] ?? 1;
    _categoryName = widget.transaction['categoryName'] ?? "Uncategorized";

    // Check if Manual Transaction (patternId is NULL)
    _isManual = widget.transaction['patternId'] == null;

    // Initialize Controllers with current values
    _amountController = TextEditingController(
      text: widget.transaction['amount'].toString(),
    );
    _noteController = TextEditingController(
      text:
          widget.transaction['sender'] == "Manual Entry"
              ? (widget.transaction['body'] ?? "")
              : widget.transaction['sender'],
    );
    _selectedDate = DateTime.fromMillisecondsSinceEpoch(
      widget.transaction['date'],
    );

    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
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

  Future<void> _saveChanges() async {
    final newAmount = double.tryParse(_amountController.text);
    if (newAmount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid Amount")));
      return;
    }

    final newNote = _noteController.text.trim();

    final updatedRow = {
      'id': widget.transaction['id'],
      'amount': newAmount,
      'date': _selectedDate.millisecondsSinceEpoch,
      'sender':
          newNote.isEmpty
              ? "Manual Entry"
              : newNote, // Use Note as Sender for manual
      'body': newNote, // Store note in body as well
    };

    await DatabaseHelper.instance.updateTransaction(updatedRow);

    setState(() {
      _isEditing = false;
      // Update local widget data for display
      widget.transaction['amount'] = newAmount;
      widget.transaction['date'] = _selectedDate.millisecondsSinceEpoch;
      widget.transaction['sender'] = updatedRow['sender'];
      widget.transaction['body'] = updatedRow['body'];
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Transaction Updated")));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Delete Transaction"),
            content: const Text(
              "Are you sure you want to delete this transaction? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteTransaction(widget.transaction['id']);
      if (mounted) {
        Navigator.pop(context, true); // Return true to refresh details
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
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

  // Copied from SettingsPage for consistency
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

  Future<void> _showCreateCategoryDialog() async {
    final controller = TextEditingController();
    Color selectedColor = _categoryColors[0]; // Default to Red

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text("New Category"),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: "Category Name",
                          border: OutlineInputBorder(),
                          hintText: "e.g. Utilities",
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
                          color: selectedColor.value,
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
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = widget.transaction['type'] == 'credit';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Details"),
        actions:
            _isManual
                ? [
                  if (!_isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _confirmDelete,
                    ),
                  IconButton(
                    icon: Icon(_isEditing ? Icons.save : Icons.edit),
                    onPressed: () {
                      if (_isEditing) {
                        _saveChanges();
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
                  ),
                ]
                : null, // No edit option for automated transactions
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
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
                          isCredit
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? Colors.green : Colors.red,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // EDITABLE AMOUNT
                    _isEditing
                        ? SizedBox(
                          width: 150,
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isCredit ? Colors.green : Colors.red,
                            ),
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                            ),
                          ),
                        )
                        : Text(
                          "${widget.transaction['amount']}",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isCredit ? Colors.green : Colors.red,
                          ),
                        ),

                    const SizedBox(height: 8),

                    // EDITABLE DATE
                    InkWell(
                      onTap: _isEditing ? _pickDate : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat.yMMMMEEEEd().add_jm().format(
                              _selectedDate,
                            ),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (_isEditing)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 40),

              // Details
              if (_isEditing)
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: "Note / Payee",
                    border: OutlineInputBorder(),
                  ),
                )
              else
                _detailRow("Sender", widget.transaction['sender']),

              const SizedBox(height: 20),

              // Category Row (Always Clickable)
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

              if (!_isEditing) ...[
                const Text(
                  "Original Message / Note",
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
            ],
          ),
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
