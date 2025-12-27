import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../app_card.dart';

class InsightBlock extends StatelessWidget {
  final String title;
  final String amount;
  final String subtitle;
  final bool isPositive;
  final bool isGood; // e.g. Expense down is good, Income up is good

  const InsightBlock({
    super.key,
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.isPositive,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    // Determine sentiment color
    final sentimentColor = isGood ? AppColors.income : AppColors.expense;
    final arrowIcon = isPositive ? Icons.arrow_upward : Icons.arrow_downward;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: sentimentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(arrowIcon, size: 16, color: sentimentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: sentimentColor,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
