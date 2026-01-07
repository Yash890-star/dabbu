import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../viewmodels/home_view_model.dart';
import '../utils/app_colors.dart';
import '../utils/cms.dart';

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

  void _showTallyDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now();
    double? calculatedBalanceForDate;
    bool isLoading = false;

    // Helper to update calculated balance
    Future<void> updateCalculatedBalance(
      StateSetter setDialogState,
      DateTime date,
    ) async {
      setDialogState(() {
        isLoading = true;
      });
      final bal = await widget.viewModel.getLiquidBalanceAt(date);
      if (mounted) {
        setDialogState(() {
          calculatedBalanceForDate = bal;
          isLoading = false;
        });
      }
    }

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Initial load
              if (calculatedBalanceForDate == null && !isLoading) {
                updateCalculatedBalance(setDialogState, selectedDate);
              }

              final currency = CMS.common['currency_symbol'] ?? '₹';

              return AlertDialog(
                title: const Text("Tally Balance"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Enter the total available balance from your bank app(s).",
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Calculated Balance Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Expected in App:",
                            style: TextStyle(fontSize: 12),
                          ),
                          isLoading
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                NumberFormat.currency(
                                  symbol: currency,
                                ).format(calculatedBalanceForDate ?? 0.0),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _balanceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Actual Balance",
                        border: OutlineInputBorder(),
                        prefixText: "₹ ",
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          final newDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            DateTime.now().hour,
                            DateTime.now().minute,
                          );
                          setDialogState(() {
                            selectedDate = newDate;
                          });
                          updateCalculatedBalance(setDialogState, newDate);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Date",
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat.yMMMd().format(selectedDate)),
                            const Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: "Note (Optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(CMS.common['cancel']!),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final val = double.tryParse(_balanceController.text);
                      if (val == null) return;

                      Navigator.pop(ctx);
                      final diff = await widget.viewModel.addCheckpoint(
                        val,
                        _noteController.text,
                        date: selectedDate,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Balance Tallied successfully!"),
                          ),
                        );
                        setState(() {}); // Rebuild UI

                        // Check for significant diff and promp adjustment
                        if (diff.abs() > 0.01) {
                          _handlePostTallyAdjustment(diff, selectedDate);
                        }
                      }
                      _balanceController.clear();
                      _noteController.clear();
                    },
                    child: const Text("Confirm"),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _handlePostTallyAdjustment(double diff, DateTime date) async {
    if (diff == 0) return;

    final isLeak = diff < 0;
    final absDiff = diff.abs();
    final currency = CMS.common['currency_symbol'] ?? '₹';
    final formattedDiff = NumberFormat.currency(
      symbol: currency,
    ).format(absDiff);

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(isLeak ? "Leak Detected!" : "Money Found!"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLeak
                      ? "The actual balance is less than expected by $formattedDiff."
                      : "The actual balance is more than expected by $formattedDiff.",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Would you like to create an adjustment transaction to correct this?",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Ignore"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await widget.viewModel.addAdjustmentTransaction(diff, date);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Adjustment transaction created."),
                      ),
                    );
                  }
                },
                child: const Text("Auto-Correct"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final checkpoints = vm.checkpoints;
    final currentCalc = vm.currentLiquidBalance;
    final currency = CMS.common['currency_symbol'] ?? '₹';

    return Scaffold(
      appBar: AppBar(title: const Text("Balance Tally")),
      body: Column(
        children: [
          // 1. Current Status (Small Card)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "CALCULATED LIQUID BALANCE",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      NumberFormat.currency(
                        symbol: currency,
                      ).format(currentCalc),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Based on your transactions",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Tally History Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      "Tally History",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Colors.blue,
                      ),
                      tooltip: "Force Recalculate",
                      onPressed: () async {
                        await vm.refreshData();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Recalculated balances."),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  "${checkpoints.length} Records",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // 3. History List
          Expanded(
            child:
                checkpoints.isEmpty
                    ? const Center(
                      child: Text(
                        "No tally history yet.\nTap 'Tally Now' to start.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: checkpoints.length,
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

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  isPerfect
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : (isLeak
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : Colors.blue.withValues(alpha: 0.1)),
                              child: Icon(
                                isPerfect
                                    ? Icons.check
                                    : (isLeak ? Icons.remove : Icons.add),
                                color:
                                    isPerfect
                                        ? Colors.green
                                        : (isLeak ? Colors.red : Colors.blue),
                              ),
                            ),
                            title: Text(
                              DateFormat('MMM d, yyyy').format(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  DateFormat('h:mm a').format(date),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
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
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showTallyDialog(context),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text("Tally Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
