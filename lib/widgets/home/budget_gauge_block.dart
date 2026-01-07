import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../app_card.dart';

class BudgetGaugeBlock extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final String currencySymbol;
  final VoidCallback? onTap;

  const BudgetGaugeBlock({
    super.key,
    required this.totalBudget,
    required this.totalSpent,
    this.currencySymbol = '₹',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark;

    if (totalBudget <= 0) {
      return AppCard(
        child: SizedBox(
          height: 200, // Keep consistent height
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        "Set Monthly Budget",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final remaining = totalBudget - totalSpent;
    final isOverspent = remaining < 0;
    final spentRatio = (totalSpent / totalBudget).clamp(0.0, 1.0);
    final percentage = ((totalSpent / totalBudget) * 100).toStringAsFixed(1);

    // Determine color based on health
    Color healthColor = AppColors.income; // Healthy (Green)
    if (spentRatio > 0.9) {
      healthColor = AppColors.expense; // Critical (Red)
    } else if (spentRatio > 0.7) {
      healthColor = AppColors.archiveIcon; // Warning (Orange)
    }

    String statusText = "Left";
    String amountText = "$currencySymbol${remaining.toStringAsFixed(0)}";
    Color statusColor = healthColor;

    if (isOverspent) {
      statusText = "Overspent";
      amountText = "$currencySymbol${(-remaining).toStringAsFixed(0)}";
      statusColor = AppColors.expense;
    }

    return AppCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Budget Status",
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: statusColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: spentRatio,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$percentage% Used",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  "Spent: $currencySymbol${totalSpent.toStringAsFixed(0)} / $currencySymbol${totalBudget.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
