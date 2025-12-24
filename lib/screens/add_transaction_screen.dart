import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class AddTransactionScreen extends StatefulWidget {
  final int? initialGoalId;
  const AddTransactionScreen({super.key, this.initialGoalId});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = 'debit'; // 'debit' or 'credit'
  DateTime _selectedDate = DateTime.now();
  int _selectedCategoryId = 1; // Default to 'Uncategorized'
  // Note: We need to load categories dynamically
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialGoalId != null) {
      _type = 'credit';
    }
    _loadCategories();
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
      await DatabaseHelper.instance.insertTransaction({
        'amount': amount,
        'sender': noteText.isEmpty ? "Manual Entry" : noteText,
        'body': "Manually added transaction",
        'date': _selectedDate.millisecondsSinceEpoch,
        'type': _type,
        'categoryId': _selectedCategoryId,
        'patternId': null, // Explicitly null for manual
        'goalId': widget.initialGoalId,
      });

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
    return Scaffold(
      appBar: AppBar(title: const Text("Add Transaction")),
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

            // 2. Type (Credit/Debit)
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
                      : const Text(
                        "Save Transaction",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
