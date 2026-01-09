import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/custom_input.dart';
import '../widgets/common/step_indicator.dart';

class TallyWizardScreen extends StatefulWidget {
  final HomeViewModel viewModel;

  const TallyWizardScreen({super.key, required this.viewModel});

  @override
  State<TallyWizardScreen> createState() => _TallyWizardScreenState();
}

class _TallyWizardScreenState extends State<TallyWizardScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _balanceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int _currentStep = 0;
  DateTime _selectedDate = DateTime.now();
  double? _calculatedBalance;
  double? _enteredBalance;
  double _difference = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCalculatedBalance();
  }

  Future<void> _fetchCalculatedBalance() async {
    setState(() {});
    final bal = await widget.viewModel.getLiquidBalanceAt(_selectedDate);
    if (mounted) {
      setState(() {
        _calculatedBalance = bal;
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate Input
      final val = double.tryParse(_balanceController.text);
      if (val == null) return;

      setState(() {
        _enteredBalance = val;
        _difference = val - (_calculatedBalance ?? 0);
      });
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      // Finish
      _finishTally();
    }
  }

  Future<void> _finishTally({bool createAdjustment = false}) async {
    // Add Checkpoint
    await widget.viewModel.addCheckpoint(
      _enteredBalance!,
      _noteController.text,
      date: _selectedDate,
    );

    if (createAdjustment && _difference.abs() > 0.01) {
      await widget.viewModel.addAdjustmentTransaction(
        _difference,
        _selectedDate,
      );
    }

    if (mounted) {
      Navigator.pop(context, true); // Return true to refresh parent
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Balance Tally"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: StepIndicator(currentStep: _currentStep, totalSteps: 3),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Input(),
                _buildStep2Reveal(),
                _buildStep3Fix(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Input() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Text(
            "Check your bank",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the total available balance from all your liquid accounts.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 32),
          CustomInput(
            controller: _balanceController,
            label: "Actual Balance",
            hint: "0.00",
            prefixIcon: Icons.currency_rupee, // Or symbol
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
                _fetchCalculatedBalance();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Date: ${DateFormat.yMMMd().format(_selectedDate)}"),
                  const Icon(Icons.calendar_today, size: 16),
                ],
              ),
            ),
          ),
          const Spacer(),
          AppButton(label: "Next", onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildStep2Reveal() {
    final diff = _difference;
    final isMatch = diff.abs() < 1.0;
    final isGood = diff > 0; // Found money?

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Text(
            "The Reveal",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  isMatch
                      ? "Perfect Match!"
                      : (isGood ? "Money Found!" : "Leak Detected!"),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        isMatch
                            ? AppColors.income
                            : (isGood ? AppColors.income : AppColors.expense),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Dabbu Thought",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          "₹${NumberFormat.compact().format(_calculatedBalance ?? 0)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      "VS",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "You Have",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          "₹${NumberFormat.compact().format(_enteredBalance ?? 0)}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isMatch || isGood
                            ? AppColors.income
                            : AppColors.expense)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isMatch
                        ? "Balances are in sync."
                        : (isGood
                            ? "You have ₹${diff.toStringAsFixed(2)} more than expected."
                            : "You are missing ₹${diff.abs().toStringAsFixed(2)}."),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isMatch || isGood
                              ? AppColors.income
                              : AppColors.expense,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AppButton(
            label: isMatch ? "Finish" : "Resolve",
            onPressed:
                isMatch
                    ? () => _finishTally(createAdjustment: false)
                    : _nextStep,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Fix() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Text(
            "Resolve Difference",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            "You can auto-create a transaction to fix this discrepancy of ₹${_difference.abs().toStringAsFixed(2)}.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          CustomInput(
            controller: _noteController,
            label: "Note for Adjustment",
            hint: "e.g., Forgot cash spend",
          ),
          const Spacer(),
          AppButton(
            label: "Auto-Correct Balance",
            onPressed: () => _finishTally(createAdjustment: true),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _finishTally(createAdjustment: false),
            child: const Text("Ignore Difference"),
          ),
        ],
      ),
    );
  }
}
