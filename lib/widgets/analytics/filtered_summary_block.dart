import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../app_card.dart';
import 'package:intl/intl.dart';

class FilteredSummaryBlock extends StatelessWidget {
  final String dateLabel;
  final int count;
  final double totalCredit;
  final double totalDebit;
  final String currencySymbol;

  const FilteredSummaryBlock({
    super.key,
    required this.count,
    required this.totalCredit,
    required this.totalDebit,
    required this.currencySymbol,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      // AppCard might not support backgroundColor directly.
      // Using standard AppCard theme.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Date & Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$count txns",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Bottom Row: Spent vs Earned
          IntrinsicHeight(
            child: Row(
              children: [
                // Spend (Left)
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: "Spent",
                    amount: totalDebit,
                    color: AppColors.expense,
                    icon: Icons.arrow_upward,
                  ),
                ),
                // Divider
                VerticalDivider(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  thickness: 1,
                  width: 32,
                ),
                // Earned (Right)
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: "Earned",
                    amount: totalCredit,
                    color: AppColors.income,
                    icon: Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          NumberFormat.currency(symbol: currencySymbol).format(amount),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
