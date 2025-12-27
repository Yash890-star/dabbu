import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../viewmodels/transaction_detail_view_model.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final TransactionDetailViewModel _viewModel = TransactionDetailViewModel();

  // Edit Mode State - UI specific
  bool _isEditing = false;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _viewModel.init(widget.transaction);

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
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _updateCategory(int newCatId, String newCatName) async {
    await _viewModel.updateCategory(newCatId, newCatName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CMS.transaction['category_updated']!)),
      );
    }
  }

  Future<void> _saveChanges() async {
    final newAmount = double.tryParse(_amountController.text);
    if (newAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CMS.transaction['invalid_amount']!)),
      );
      return;
    }

    final newNote = _noteController.text.trim();

    await _viewModel.saveChanges(newAmount, newNote, _selectedDate);

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CMS.transaction['transaction_updated']!)),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.transaction['delete_dialog_title']!),
            content: Text(CMS.transaction['delete_dialog_content']!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(CMS.common['cancel']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(CMS.common['delete']!),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _viewModel.deleteTransaction();
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
                leading: Icon(
                  Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(CMS.transaction['create_category']!),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateCategoryDialog();
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _viewModel.allCategories.length,
                  itemBuilder: (ctx, i) {
                    final cat = _viewModel.allCategories[i];
                    return ListTile(
                      title: Text(cat['name']),
                      trailing:
                          _viewModel.selectedCategoryId == cat['id']
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
      await _viewModel.updateGoal(
        newGoalId,
        newGoalName,
        isGoalAddition: isGoalAddition,
      );
    } catch (e) {
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
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  CMS.transaction['select_goal_title']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _viewModel.allGoals.length,
                  itemBuilder: (ctx, i) {
                    final goal = _viewModel.allGoals[i];
                    return ListTile(
                      leading: Icon(
                        Icons.savings,
                        color: Color(goal['color'] ?? Colors.blue.toARGB32()),
                      ),
                      title: Text(goal['name']),
                      trailing:
                          _viewModel.selectedGoalId == goal['id']
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                      onTap: () async {
                        Navigator.pop(ctx); // Close list

                        // Ask for Impact
                        await showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: Text(
                                  (CMS.transaction['impact_dialog_title']
                                          as String)
                                      .replaceFirst('{goalName}', goal['name']),
                                ),
                                content: Text(
                                  CMS.transaction['impact_dialog_content']!,
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
                                    child: Text(
                                      CMS.transaction['impact_subtract']!,
                                      style: const TextStyle(
                                        color: Colors.orange,
                                      ),
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
                                    child: Text(CMS.transaction['impact_add']!),
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

  Future<void> _showCreateCategoryDialog() async {
    final controller = TextEditingController();
    Color selectedColor = _viewModel.categoryColors[0]; // Default to Red

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
                        decoration: InputDecoration(
                          labelText: CMS.settings['category_name_label']!,
                          border: const OutlineInputBorder(),
                          hintText: CMS.settings['category_name_hint']!,
                        ),
                        textCapitalization: TextCapitalization.sentences,
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
                    child: Text(CMS.common['cancel']!),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.isNotEmpty) {
                        int newId = await _viewModel.addNewCategory(
                          controller.text,
                          selectedColor.toARGB32(),
                        );
                        await _updateCategory(
                          newId,
                          controller.text,
                        ); // Assign immediately
                        if (ctx.mounted) Navigator.pop(ctx);
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
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        final isCredit = _viewModel.transaction['type'] == 'credit';

        return Scaffold(
          appBar: AppBar(
            title: Text(CMS.transaction['details_title']!),
            actions:
                _viewModel.isManual
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
                    : null,
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
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                          child: Icon(
                            isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
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
                              "${_viewModel.transaction['amount']}",
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
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                      decoration: InputDecoration(
                        labelText: CMS.transaction['note_label']!,
                        border: const OutlineInputBorder(),
                      ),
                    )
                  else
                    _detailRow(
                      CMS.transaction['sender_label']!,
                      _viewModel.transaction['sender'],
                    ),

                  const SizedBox(height: 20),

                  // Category Row (Always Clickable)
                  InkWell(
                    onTap: _showCategoryPicker,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CMS.transaction['category_label']!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        Row(
                          children: [
                            Chip(
                              label: Text(_viewModel.categoryName),
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit,
                              size: 16,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // NEW: Link to Goal Row
                  if (_viewModel.allGoals.isNotEmpty) ...[
                    InkWell(
                      onTap: _showGoalPicker,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CMS.transaction['link_goal_label']!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              if (_viewModel.goalName != null)
                                Chip(
                                  avatar: const Icon(Icons.savings, size: 16),
                                  label: Text(
                                    "${_viewModel.goalName!} (${(_viewModel.transaction['is_goal_addition'] ?? 1) == 1 ? '+' : '-'})",
                                  ),
                                  backgroundColor:
                                      Theme.of(
                                        context,
                                      ).colorScheme.tertiaryContainer,
                                  labelStyle: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onTertiaryContainer,
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => _updateGoal(null, null),
                                )
                              else
                                Text(
                                  CMS.transaction['select_goal_label']!,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                              if (_viewModel.goalName == null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.edit,
                                  size: 16,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                    Text(
                      CMS.transaction['original_message_label']!,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_viewModel.transaction['body'] ?? ""),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
