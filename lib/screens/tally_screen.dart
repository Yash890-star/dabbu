import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../viewmodels/home_view_model.dart';
import '../utils/app_colors.dart';
import '../utils/cms.dart';
import 'tally_wizard_screen.dart';
import '../widgets/common/app_card.dart';

class TallyScreen extends StatefulWidget {
  final HomeViewModel viewModel;
  const TallyScreen({super.key, required this.viewModel});

  @override
  State<TallyScreen> createState() => _TallyScreenState();
}

class _TallyScreenState extends State<TallyScreen> {
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _showTallyWizard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => TallyWizardScreen(viewModel: widget.viewModel),
      ),
    );

    if (result == true) {
      await widget.viewModel.refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tally recorded successfully!")),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final checkpoints = vm.checkpoints;
    final currentCalc = vm.currentLiquidBalance;
    final currency = CMS.common['currency_symbol'] ?? '₹';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("Balance Tally"), centerTitle: true),
      body: Column(
        children: [
          // 1. Current Status (Small Card)
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    "CALCULATED LIQUID BALANCE",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    NumberFormat.currency(symbol: currency).format(currentCalc),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Based on your transactions",
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Tally History Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "History",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: "Force Recalculate",
                  onPressed: () async {
                    await vm.refreshData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Recalculated balances.")),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // 3. History List
          Expanded(
            child:
                checkpoints.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 48,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No tally history yet.\nTap 'Tally Now' to start.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: checkpoints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = checkpoints[index];
                        final date = DateTime.fromMillisecondsSinceEpoch(
                          item['date'] as int,
                        );
                        final diff = (item['diff'] as num?)?.toDouble() ?? 0.0;
                        final balance =
                            (item['balance'] as num?)?.toDouble() ?? 0.0;

                        final isPerfect = diff.abs() < 0.01;
                        final isLeak = diff < 0;

                        // Using AppCard for List Items? Or just standard Card?
                        // Standard Card is cleaner for list if AppCard is biased to Glass.
                        // But I defined AppCard to be flexible.
                        // Let's use a nice container.

                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.05),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    isPerfect
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : (isLeak
                                            ? Colors.red.withValues(alpha: 0.1)
                                            : Colors.blue.withValues(
                                              alpha: 0.1,
                                            )),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPerfect
                                    ? Icons.check
                                    : (isLeak ? Icons.remove : Icons.add),
                                color:
                                    isPerfect
                                        ? Colors.green
                                        : (isLeak ? Colors.red : Colors.blue),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              DateFormat('MMM d, yyyy').format(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              "Actual: ${NumberFormat.currency(symbol: currency).format(balance)}",
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  isPerfect
                                      ? "Matched"
                                      : (isLeak
                                          ? "- ${NumberFormat.simpleCurrency(name: '').format(diff.abs())}"
                                          : "+ ${NumberFormat.simpleCurrency(name: '').format(diff)}"),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isPerfect
                                            ? Colors.green
                                            : (isLeak
                                                ? Colors.red
                                                : Colors.blue),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  DateFormat('h:mm a').format(date),
                                  style: TextStyle(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // 4. Action Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _showTallyWizard,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "Tally Now",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
