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

  // NEW: Goal State
  int? _selectedGoalId;
  String? _goalName;
  List<Map<String, dynamic>> _allGoals = [];

  // Edit Mode State
  bool _isManual = false;
  bool _isEditing = false;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;

  // Local Mutable Copy
  late Map<String, dynamic> _localTransaction;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of the transaction data
    _localTransaction = Map<String, dynamic>.from(widget.transaction);

    _selectedCategoryId = _localTransaction['categoryId'] ?? 1;
    _categoryName = _localTransaction['categoryName'] ?? "Uncategorized";

    // Initialize Goal from transaction
    _selectedGoalId = _localTransaction['goalId'];

    // Check if Manual Transaction (patternId is NULL)
    _isManual = _localTransaction['patternId'] == null;

    // Initialize Controllers with current values
    _amountController = TextEditingController(
      text: _localTransaction['amount'].toString(),
    );
    _noteController = TextEditingController(
      text:
          _localTransaction['sender'] == "Manual Entry"
              ? (_localTransaction['body'] ?? "")
              : _localTransaction['sender'],
    );
    _selectedDate = DateTime.fromMillisecondsSinceEpoch(
      _localTransaction['date'],
    );

    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final cats = await DatabaseHelper.instance.getCategories();
    final goals =
        await DatabaseHelper.instance.getAllGoals(); // <--- Fetch Goals

    String? currentGoalName;
    if (_selectedGoalId != null) {
      final found = goals.where((g) => g['id'] == _selectedGoalId).firstOrNull;
      currentGoalName = found?['name'];
    }

    setState(() {
      _allCategories = cats;
      _allGoals = goals;
      _goalName = currentGoalName;
    });
  }

  Future<void> _updateCategory(int newCatId, String newCatName) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'transactions',
      {'categoryId': newCatId},
      where: 'id = ?',
      whereArgs: [_localTransaction['id']],
    );

    setState(() {
      _selectedCategoryId = newCatId;
      _categoryName = newCatName;
      _localTransaction['categoryId'] = newCatId;
      _localTransaction['categoryName'] = newCatName;
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
      'id': _localTransaction['id'],
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
      _localTransaction['amount'] = newAmount;
      _localTransaction['date'] = _selectedDate.millisecondsSinceEpoch;
      _localTransaction['sender'] = updatedRow['sender'];
      _localTransaction['body'] = updatedRow['body'];
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
      await DatabaseHelper.instance.deleteTransaction(_localTransaction['id']);
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

  Future<void> _updateGoal(
    int? newGoalId,
    String? newGoalName, {
    bool isGoalAddition = true,
  }) async {
    try {
      print(
        "Debug: Assigning Goal ID: $newGoalId, Name: $newGoalName, Impact: $isGoalAddition",
      );

      final db = await DatabaseHelper.instance.database;
      await db.update(
        'transactions',
        {'goalId': newGoalId, 'is_goal_addition': isGoalAddition ? 1 : 0},
        where: 'id = ?',
        whereArgs: [widget.transaction['id']],
      );

      if (mounted) {
        setState(() {
          _selectedGoalId = newGoalId;
          _goalName = newGoalName;
          _localTransaction['goalId'] = newGoalId;
          _localTransaction['is_goal_addition'] = isGoalAddition ? 1 : 0;
        });

        // Refresh data to ensure consistency (and if goal name was null for some reason, fetch it)
        await _loadData();
      }
    } catch (e) {
      print("Error updating goal: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _showGoalPicker() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Select Savings Goal",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _allGoals.length,
                  itemBuilder: (ctx, i) {
                    final goal = _allGoals[i];
                    return ListTile(
                      leading: Icon(
                        Icons.savings,
                        color: Color(goal['color'] ?? Colors.blue.value),
                      ),
                      title: Text(goal['name']),
                      trailing:
                          _selectedGoalId == goal['id']
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                      onTap: () async {
                        Navigator.pop(ctx); // Close list

                        // Ask for Impact
                        await showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text("Impact on '${goal['name']}'?"),
                                content: const Text(
                                  "Is this money adding to the goal or being withdrawn from it?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _updateGoal(
                                        goal['id'],
                                        goal['name'],
                                        isGoalAddition: false,
                                      );
                                    },
                                    child: const Text(
                                      "Subtract (Withdraw)",
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _updateGoal(
                                        goal['id'],
                                        goal['name'],
                                        isGoalAddition: true,
                                      );
                                    },
                                    child: const Text("Add (Deposit)"),
                                  ),
                                ],
                              ),
                        );
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
                        await _loadData(); // Refresh local list
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
                _detailRow("Sender", _localTransaction['sender']),

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

              // NEW: Link to Goal Row
              if (_allGoals.isNotEmpty) ...[
                InkWell(
                  onTap: _showGoalPicker,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Link to Goal",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Row(
                        children: [
                          if (_goalName != null)
                            Chip(
                              avatar: const Icon(Icons.savings, size: 16),
                              label: Text(
                                "${_goalName!} (${(_localTransaction['is_goal_addition'] ?? 1) == 1 ? '+' : '-'})",
                              ),
                              backgroundColor: Colors.amber.shade50,
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _updateGoal(null, null),
                            )
                          else
                            const Text(
                              "Select Goal",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                          if (_goalName == null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

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
                  child: Text(_localTransaction['body'] ?? ""),
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
