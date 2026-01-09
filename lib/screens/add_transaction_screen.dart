import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../viewmodels/add_transaction_view_model.dart';

class AddTransactionScreen extends StatefulWidget {
  final int? initialGoalId;
  final Map<String, dynamic>? transaction; // For Edit Mode

  const AddTransactionScreen({super.key, this.initialGoalId, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final AddTransactionViewModel _viewModel = AddTransactionViewModel();

  // Controllers remain in UI for binding
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.init(
      initialGoalId: widget.initialGoalId,
      transaction: widget.transaction,
    );

    // Initialize Controllers
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!['amount'].toString();
      _noteController.text = widget.transaction!['sender'] ?? "";
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _viewModel.setSelectedDate(picked);
    }
  }

  Future<void> _saveTransaction() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    final error = await _viewModel.saveTransaction(
      amountText: _amountController.text.trim(),
      noteText: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (error == null) {
      // Success
      Navigator.pop(context, true);
    } else {
      // Error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.transaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? CMS.transaction['edit_title']!
              : CMS.transaction['add_title']!,
        ),
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return SingleChildScrollView(
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
                  decoration: InputDecoration(
                    labelText: CMS.transaction['amount_label']!,
                    prefixText: "${CMS.common['currency_symbol']!} ",
                    border: const UnderlineInputBorder(), // Simplified
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // 2. Type Selector (Simplified to standard Segmented Look if possible, or keeping chips)
                // Keeping chips for now as they are clear, but maybe remove container border for cleaner look.
                if (_viewModel.isGoalMode) ...[
                  // A. GOAL IMPACT
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CMS.transaction['impact_title']!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(CMS.transaction['impact_add']!),
                              ),
                              selected: _viewModel.isGoalAddition,
                              onSelected: (val) {
                                if (val) _viewModel.setIsGoalAddition(true);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  CMS.transaction['impact_subtract']!,
                                ),
                              ),
                              selected: !_viewModel.isGoalAddition,
                              onSelected: (val) {
                                if (val) _viewModel.setIsGoalAddition(false);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // B. TRANSACTION TYPE (Money Flow)
                  Text(
                    CMS.transaction['flow_label']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(CMS.transaction['flow_expense']!),
                          ),
                          selected: _viewModel.type == 'debit',
                          onSelected: (val) {
                            if (val) _viewModel.setType('debit');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(CMS.transaction['flow_income']!),
                          ),
                          selected: _viewModel.type == 'credit',
                          onSelected: (val) {
                            if (val) _viewModel.setType('credit');
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
                          label: Center(
                            child: Text(CMS.transaction['type_expense']!),
                          ),
                          selected: _viewModel.type == 'debit',
                          selectedColor: AppColors.expenseBackground,
                          labelStyle: TextStyle(
                            color:
                                _viewModel.type == 'debit'
                                    ? AppColors.expense
                                    : null,
                          ),
                          onSelected: (val) {
                            if (val) _viewModel.setType('debit');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(CMS.transaction['type_income']!),
                          ),
                          selected: _viewModel.type == 'credit',
                          selectedColor: AppColors.incomeBackground,
                          labelStyle: TextStyle(
                            color:
                                _viewModel.type == 'credit'
                                    ? AppColors.income
                                    : null,
                          ),
                          onSelected: (val) {
                            if (val) _viewModel.setType('credit');
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
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: CMS.transaction['date_label']!,
                      border: const UnderlineInputBorder(), // Simplified
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat.yMMMd().add_jm().format(
                        _viewModel.selectedDate,
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. Note / Payee
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: CMS.transaction['note_label']!,
                    hintText: CMS.transaction['note_hint']!,
                    border: const UnderlineInputBorder(), // Simplified
                    prefixIcon: const Icon(Icons.description),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),

                // 5. Category
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: CMS.transaction['category_label']!,
                    border: const UnderlineInputBorder(), // Simplified
                    prefixIcon: const Icon(Icons.category),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _viewModel.selectedCategoryId,
                      isDense: true,
                      isExpanded: true,
                      items:
                          _viewModel.categories.map((cat) {
                            return DropdownMenuItem<int>(
                              value: cat['id'],
                              child: Text(cat['name']),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _viewModel.setSelectedCategoryId(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Save Button
                FilledButton(
                  // Use FilledButton for modern look
                  onPressed: _viewModel.isLoading ? null : _saveTransaction,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _viewModel.isLoading
                          ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            isEditing
                                ? CMS.transaction['update_btn']!
                                : CMS.transaction['save_btn']!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
