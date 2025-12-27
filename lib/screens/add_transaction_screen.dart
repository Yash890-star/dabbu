import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  final int? initialGoalId;
  final Map<String, dynamic>? transaction; // For Edit Mode

  const AddTransactionScreen({super.key, this.initialGoalId, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'debit'; // 'debit' or 'credit'
  bool _isGoalAddition = true; // Goal Impact: Add vs Subtract

  DateTime _selectedDate = DateTime.now();
  int _selectedCategoryId = 1; // Default to 'Uncategorized'
  // Note: We need to load categories dynamically
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;

  // Goal Mode State
  bool get _isGoalMode =>
      widget.initialGoalId != null ||
      (widget.transaction != null && widget.transaction!['goalId'] != null);
  int? get _activeGoalId =>
      widget.initialGoalId ?? widget.transaction?['goalId'];

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.transaction != null) {
      // --- Edit Mode ---
      final tx = widget.transaction!;
      _amountController.text = tx['amount'].toString();
      _noteController.text =
          tx['sender'] ?? ""; // Sender column stores manual note
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      _type = tx['type'];
      _selectedCategoryId = tx['categoryId'] ?? 1;
      // Load goal impact state (default to add/1 if null or 1)
      final existingFlag = tx['is_goal_addition'];
      _isGoalAddition = (existingFlag == null || existingFlag == 1);
    } else {
      // --- Create Mode ---
      if (_isGoalMode) {
        // Default to Adding to Goal
        _isGoalAddition = true;
        // Default to Expense (Debit) for savings
        _type = 'debit';
      }
    }
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        // Ensure selected ID is valid, else default to first
        if (_categories.isNotEmpty &&
            !_categories.any((c) => c['id'] == _selectedCategoryId)) {
          _selectedCategoryId = _categories.first['id'];
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          DateTime.now().hour,
          DateTime.now().minute,
        );
      });
    }
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text.trim();
    final noteText = _noteController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final txData = {
        'amount': amount,
        'sender':
            noteText.isEmpty
                ? (_isGoalMode ? "Goal Contribution" : "Manual Entry")
                : noteText,
        'body': "Manually added transaction",
        'date': _selectedDate.millisecondsSinceEpoch,
        'type': _type, // Actual Money Flow
        'categoryId': _selectedCategoryId,
        'patternId': null, // Explicitly null for manual
        'goalId': _activeGoalId,
        'is_goal_addition': _isGoalAddition ? 1 : 0, // Explicit Goal Impact
      };

      if (widget.transaction != null) {
        // Update
        txData['id'] = widget.transaction!['id']; // Add ID for update
        await DatabaseHelper.instance.updateTransaction(txData);
      } else {
        // Insert
        await DatabaseHelper.instance.insertTransaction(txData);
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        true,
      ); // Return true to indicate success/reload needed
    } catch (e) {
      debugPrint("Error saving manual tx: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.transaction != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Transaction" : "Add Transaction"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Amount
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Amount",
                prefixText: "₹ ",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 2. Type Selector
            if (_isGoalMode) ...[
              // A. GOAL IMPACT
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Impact on Goal",
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text("Add (Deposit)")),
                            selected: _isGoalAddition,
                            selectedColor: Colors.blue,
                            labelStyle: TextStyle(
                              color:
                                  _isGoalAddition ? Colors.white : Colors.black,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _isGoalAddition = true);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text("Subtract (Withdraw)"),
                            ),
                            selected: !_isGoalAddition,
                            selectedColor: Colors.orange,
                            labelStyle: TextStyle(
                              color:
                                  !_isGoalAddition
                                      ? Colors.white
                                      : Colors.black,
                            ),
                            onSelected: (val) {
                              if (val) setState(() => _isGoalAddition = false);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // B. TRANSACTION TYPE (Money Flow)
              const Text(
                "Actual Money Flow:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Paid Out (Expense)")),
                      selected: _type == 'debit',
                      selectedColor: Colors.red.shade100,
                      labelStyle: TextStyle(
                        color: _type == 'debit' ? Colors.red : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _type = 'debit');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Received (Income)")),
                      selected: _type == 'credit',
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color: _type == 'credit' ? Colors.green : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _type = 'credit');
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // NORMAL MODE: Expense/Income
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Expense (Debit)")),
                      selected: _type == 'debit',
                      selectedColor: Colors.red.shade100,
                      labelStyle: TextStyle(
                        color: _type == 'debit' ? Colors.red : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _type = 'debit');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text("Income (Credit)")),
                      selected: _type == 'credit',
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color: _type == 'credit' ? Colors.green : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _type = 'credit');
                      },
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // 3. Date
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Date",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat.yMMMd().add_jm().format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Note / Payee
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: "Note / Payee",
                hintText: "e.g. Cash, Lunch, Taxi",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // 5. Category
            InputDecorator(
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedCategoryId,
                  isDense: true,
                  isExpanded: true,
                  items:
                      _categories.map((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'],
                          child: Text(cat['name']),
                        );
                      }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategoryId = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveTransaction,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        isEditing ? "Update Transaction" : "Save Transaction",
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
