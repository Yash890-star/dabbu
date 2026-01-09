import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../app_card.dart';
import '../common/glow_gauge.dart';

class BudgetGaugeBlock extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final String currencySymbol;
  final VoidCallback? onTap;
  final bool isPrivacyEnabled;

  const BudgetGaugeBlock({
    super.key,
    required this.totalBudget,
    required this.totalSpent,
    this.currencySymbol = '₹',
    this.onTap,
    this.isPrivacyEnabled = false,
  });

  String _formatAmount(double amount) {
    if (isPrivacyEnabled) return "••••"; // Privacy mask
    return "$currencySymbol${amount.toStringAsFixed(0)}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (totalBudget <= 0) {
      return AppCard(
        child: SizedBox(
          height: 180,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "No Monthly Budget Set",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text("Set Budget"),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final remaining = totalBudget - totalSpent;
    final isOverspent = remaining < 0;
    final spentRatio = (totalSpent / totalBudget).clamp(0.0, 1.0);
    final percentage = ((totalSpent / totalBudget) * 100).toStringAsFixed(0);

    return AppCard(
      padding: EdgeInsets.zero, // Important for layout
      child: Stack(
        children: [
          // Background Glow if critical (optional, maybe later)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Monthly Budget",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isOverspent ? "Overspent" : "Left",
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    isOverspent
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isOverspent
                                  ? _formatAmount(-remaining)
                                  : _formatAmount(remaining),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color:
                                    isOverspent
                                        ? AppColors.error
                                        : theme.colorScheme.onSurface,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Edit pill
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Modify",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The Gauge
                      Positioned.fill(
                        child: GlowGauge(
                          progress: spentRatio,
                          durationSeconds: 1.5,
                        ),
                      ),

                      // Central Text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$percentage%",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            "Used",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Bottom labels moved out of Stack to prevent overlap
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _buildMiniStat(
                        theme,
                        "Spent",
                        _formatAmount(totalSpent),
                      ),
                    ),
                    Flexible(
                      child: _buildMiniStat(
                        theme,
                        "Limit",
                        _formatAmount(totalBudget),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
