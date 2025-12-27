import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../app_card.dart';

class SublimitBlock extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final Map<int, double> categorySpending;
  final String currencySymbol;

  const SublimitBlock({
    super.key,
    required this.categories,
    required this.categorySpending,
    this.currencySymbol = '₹',
  });

  @override
  Widget build(BuildContext context) {
    // Filter categories that have a budget limit > 0
    final budgetedCategories =
        categories.where((c) {
          final limit = (c['budgetLimit'] as num?)?.toDouble() ?? 0.0;
          return limit > 0;
        }).toList();

    if (budgetedCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by usage percentage descending
    budgetedCategories.sort((a, b) {
      final limitA = (a['budgetLimit'] as num).toDouble();
      final spentA = categorySpending[a['id']] ?? 0.0;
      final ratioA = spentA / limitA;

      final limitB = (b['budgetLimit'] as num).toDouble();
      final spentB = categorySpending[b['id']] ?? 0.0;
      final ratioB = spentB / limitB;

      return ratioB.compareTo(ratioA);
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Category Limits",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...budgetedCategories.take(4).map((cat) {
            // Show top 4
            final limit = (cat['budgetLimit'] as num).toDouble();
            final spent = (categorySpending[cat['id']] ?? 0.0);
            final remaining = limit - spent;
            final isOverspent = remaining < 0;
            final ratio = (spent / limit).clamp(0.0, 1.0);
            final name = cat['name'] as String;

            Color statusColor = AppColors.success;
            String statusText =
                "Left: $currencySymbol${remaining.toStringAsFixed(0)}";

            if (isOverspent) {
              statusColor = AppColors.expense;
              statusText =
                  "Overspent: $currencySymbol${(-remaining).toStringAsFixed(0)}";
            } else if (ratio > 0.8) {
              statusColor = AppColors.archiveIcon; // Orange
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "$currencySymbol${spent.toStringAsFixed(0)} / $currencySymbol${limit.toStringAsFixed(0)}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
