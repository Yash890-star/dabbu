import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../viewmodels/transaction_detail_view_model.dart';
import 'brain_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final TransactionDetailViewModel _viewModel = TransactionDetailViewModel();

  // Edit Mode State
  bool _isEditing = false;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _viewModel.init(widget.transaction);

    _amountController = TextEditingController(
      text: widget.transaction['amount'].toString(),
    );
    _noteController = TextEditingController(
      text: widget.transaction['note'] ?? "",
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

  // --- Actions ---

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

    await _viewModel.saveChanges(
      newAmount,
      newNote,
      _selectedDate.millisecondsSinceEpoch,
      _viewModel.isExcluded,
      _viewModel.isIgnored,
    );

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
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(CMS.common['delete']!),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _viewModel.deleteTransaction();
      if (mounted) {
        Navigator.pop(context, {
          'action': 'delete',
          'id': _viewModel.transaction['id'],
        });
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Select Category",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showCreateCategoryDialog();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _viewModel.allCategories.length,
                    itemBuilder: (ctx, i) {
                      final cat = _viewModel.allCategories[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(
                            cat['color'] ?? Colors.grey.toARGB32(),
                          ).withValues(alpha: 0.2),
                          child: Icon(
                            Icons.category,
                            color: Color(
                              cat['color'] ?? Colors.grey.toARGB32(),
                            ),
                            size: 18,
                          ),
                        ),
                        title: Text(cat['name']),
                        trailing:
                            _viewModel.selectedCategoryId == cat['id']
                                ? const Icon(
                                  Icons.check,
                                  color: AppColors.income,
                                )
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                              ? const Icon(Icons.check, color: AppColors.income)
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
    Color selectedColor = _viewModel.categoryColors[0];

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(CMS.settings['new_category_title']!),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children:
                              _viewModel.categoryColors.map((color) {
                                final isSelected =
                                    selectedColor.toARGB32() ==
                                    color.toARGB32();
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedColor = color;
                                    });
                                  },
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border:
                                          isSelected
                                              ? Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              )
                                              : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child:
                                        isSelected
                                            ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                            : null,
                                  ),
                                );
                              }).toList(),
                        ),
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
                        await _updateCategory(newId, controller.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    child: Text(CMS.transaction['create_assign_btn']!),
                  ),
                ],
              );
            },
          ),
    );
  }

  // --- UI Components ---

  Widget _buildInfoRow(String label, Widget content, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(child: content),
            if (onTap != null && _isEditing)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, {
          'action': 'update',
          'transaction': _viewModel.transaction,
        });
      },
      child: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          final isCredit = _viewModel.transaction['type'] == 'credit';
          final primaryColor = isCredit ? AppColors.income : AppColors.expense;
          final bgColor =
              isCredit
                  ? AppColors.incomeBackground
                  : AppColors.expenseBackground;

          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: const Text("Transaction Details"),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.pop(context, {
                    'action': 'update',
                    'transaction': _viewModel.transaction,
                  });
                },
              ),
              actions: [
                if (_isEditing)
                  TextButton(
                    onPressed: _saveChanges,
                    child: const Text(
                      "Save",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // --- The Receipt Card ---
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 1. Header Section
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: bgColor.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCredit
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: primaryColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _isEditing
                                  ? TextField(
                                    controller: _amountController,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "0.00",
                                    ),
                                  )
                                  : Text(
                                    "₹${_viewModel.transaction['amount']}",
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                      letterSpacing: -1,
                                    ),
                                  ),
                              const SizedBox(height: 8),
                              Text(
                                isCredit ? "Received from" : "Paid to",
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _isEditing
                                  ? Column(
                                    children: [
                                      // --- SENDER / BODY (Read Only if SMS) ---
                                      if (_viewModel.transaction['sender'] !=
                                          "Manual Entry") ...[
                                        Text(
                                          "Sender: ${_viewModel.transaction['sender']}",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        if (_viewModel.transaction['body'] !=
                                            null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            _viewModel.transaction['body'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                      ],

                                      // --- NOTE FIELD (Editable) ---
                                      TextField(
                                        controller: _noteController,
                                        decoration: const InputDecoration(
                                          labelText: "Note",
                                          border: OutlineInputBorder(),
                                          alignLabelWithHint: true,
                                        ),
                                        maxLines: 2,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                      ),
                                    ],
                                  )
                                  : Text(
                                    _viewModel.transaction['sender'] ==
                                            "Manual Entry"
                                        ? (_viewModel.transaction['body'] ??
                                            "Manual Entry")
                                        : _viewModel.transaction['sender'],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                              if ((_viewModel.transaction['note'] ?? "")
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _viewModel.transaction['note'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _isEditing ? _pickDate : null,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    DateFormat.yMMMMEEEEd().add_jm().format(
                                      _selectedDate,
                                    ),
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Divider (Dashed ideally, solid for now)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Divider(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.5),
                            height: 1,
                          ),
                        ),

                        // 2. Details Section
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                "Category",
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(
                                          _viewModel
                                                  .transaction['category_color'] ??
                                              Colors.grey.toARGB32(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _viewModel.categoryName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: _isEditing ? _showCategoryPicker : null,
                              ),
                              _buildInfoRow(
                                "Goal",
                                _viewModel.goalName != null
                                    ? Row(
                                      children: [
                                        const Icon(
                                          Icons.savings,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            _viewModel.goalName!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Text(
                                      "None",
                                      style: TextStyle(
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                onTap: _isEditing ? _showGoalPicker : null,
                              ),
                              _buildInfoRow(
                                "Status",
                                _viewModel.isIgnored
                                    ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).disabledColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "Excluded",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                    : const Text(
                                      "Active",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Action Strip ---
                  // Only show actions if NOT editing, or show different actions?
                  // Logic: When editing, we focus on fields. When viewing, we show actions.
                  if (!_isEditing)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Edit
                        _ActionItem(
                          icon: Icons.edit_rounded,
                          label: "Edit",
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                        ),
                        // Auto Rule
                        if (_viewModel.isManual == false &&
                            (_viewModel.transaction['body'] ?? "").isNotEmpty)
                          _ActionItem(
                            icon: Icons.auto_fix_high_rounded,
                            label: "Rule",
                            color:
                                Theme.of(context)
                                    .colorScheme
                                    .tertiary, // Use Tertiary for distinction but ensure visibility
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => BrainScreen(
                                        initialBody:
                                            _viewModel.transaction['body'] ??
                                            _viewModel.transaction['sender'],
                                        initialSender:
                                            _viewModel.transaction['sender'],
                                      ),
                                ),
                              );
                              if (result == true) {
                                // Refresh current transaction if updated
                                _viewModel.init(_viewModel.transaction);
                                if (context.mounted) {
                                  Navigator.pop(context, {
                                    'action': 'update',
                                    'transaction': _viewModel.transaction,
                                  });
                                }
                              }
                            },
                          ),
                        // Exclude
                        _ActionItem(
                          icon:
                              _viewModel.isIgnored
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                          label: _viewModel.isIgnored ? "Include" : "Exclude",
                          color: Colors.orange,
                          onTap: () {
                            _viewModel.toggleIgnore();
                          },
                        ),
                        // Delete
                        _ActionItem(
                          icon: Icons.delete_rounded,
                          label: "Delete",
                          color: AppColors.error,
                          onTap: _confirmDelete,
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  if (!_isEditing &&
                      (_viewModel.transaction['body'] ?? "") != "") ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CMS.transaction['original_message_label']!,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _viewModel.transaction['body'],
                              style: const TextStyle(
                                fontFamily: 'Monospace',
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
