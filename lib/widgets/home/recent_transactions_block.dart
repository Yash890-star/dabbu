import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_colors.dart';
import '../app_card.dart';

class RecentTransactionsBlock extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final VoidCallback onViewAll;

  const RecentTransactionsBlock({
    super.key,
    required this.transactions,
    required this.onViewAll,
    this.onTransactionTap,
  });

  final Function(Map<String, dynamic>)? onTransactionTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero, // Custom padding for list
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Activity",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text("View All"),
                ),
              ],
            ),
          ),

          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  "No recent transactions",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),

          ...transactions.take(5).map((tx) {
            final type = (tx['type'] as String?)?.toUpperCase() ?? '';
            final isDebit = type.contains('DEBIT');
            final color = isDebit ? AppColors.expense : AppColors.income;
            final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
            final amount = tx['amount'];
            final entity = tx['patternName'] ?? tx['sender'] ?? "Unknown";

            return Column(
              children: [
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                      color: color,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    entity ?? "Unknown",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateFormat('MMM d').format(date),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    "${isDebit ? '-' : '+'}₹${amount.toString()}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => onTransactionTap?.call(tx),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
