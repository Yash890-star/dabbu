import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/database_helper.dart';

class AddGoalDialog extends StatefulWidget {
  final VoidCallback onGoalAdded;

  const AddGoalDialog({super.key, required this.onGoalAdded});

  @override
  State<AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<AddGoalDialog> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  Color _selectedColor = AppColors.defaultGoalColor;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create Savings Goal"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: "Goal Name",
              hintText: "e.g., New Laptop",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: "Target Amount",
              prefixText: "₹ ",
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          // Simple Color Picker (Row of circles)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  AppColors.selectionColors.map((color) {
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border:
                              _selectedColor == color
                                  ? Border.all(width: 3, color: Colors.black)
                                  : null,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () async {
            final name = _nameController.text.trim();
            final amount =
                double.tryParse(_amountController.text.trim()) ?? 0.0;
            if (name.isNotEmpty && amount > 0) {
              final nav = Navigator.of(context);
              await DatabaseHelper.instance.createGoal({
                'name': name,
                'targetAmount': amount,
                'savedAmount': 0.0,
                // ignore: deprecated_member_use
                'color': _selectedColor.value,
                'deadline':
                    DateTime.now()
                        .add(const Duration(days: 365))
                        .millisecondsSinceEpoch, // Default 1 year
              });
              if (!mounted) return;
              nav.pop();
              widget.onGoalAdded();
            }
          },
          child: const Text("Create Goal"),
        ),
      ],
    );
  }
}
