import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';

class ActionStrip extends StatelessWidget {
  final VoidCallback onAddTransaction;
  // final VoidCallback onScanSms; // Removed
  final VoidCallback onManageGoals;
  final VoidCallback onAddGoal;

  const ActionStrip({
    super.key,
    required this.onAddTransaction,
    // required this.onScanSms, // Removed
    required this.onManageGoals,
    required this.onAddGoal,
    required this.onTally,
  });

  final VoidCallback onTally;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width:
                100, // Fixed width for consistent look or let them be flexible
            child: _ActionPill(
              icon: Icons.add,
              label: "Add",
              color: AppColors.primary,
              onTap: onAddTransaction,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: _ActionPill(
              icon: Icons.check_circle_outline,
              label: "Tally",
              color: Colors.teal,
              onTap: onTally,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: _ActionPill(
              icon: Icons.flag_outlined,
              label: "Goals",
              color: AppColors.archiveIcon,
              onTap: onManageGoals,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: _ActionPill(
              icon: Icons.add_task,
              label: "Add Goal",
              color: AppColors.success,
              onTap: onAddGoal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // We can recycle AppCard for the pill shape if we adjust borderRadius
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          // Using Container directly for custom pill shape look
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          alignment: Alignment.center, // Center content
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.sm), // Reduced gap
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
