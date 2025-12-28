import 'package:flutter/material.dart';
import '../utils/cms.dart';
import '../viewmodels/initial_setup_view_model.dart';
import 'sms_setup_screen.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final InitialSetupViewModel _viewModel = InitialSetupViewModel();

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final budgetStr = _budgetController.text.trim();
    final double? budget =
        budgetStr.isNotEmpty ? double.tryParse(budgetStr) : null;

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(CMS.setup['name_error']!)));
      return;
    }

    await _viewModel.saveUserData(name, budget: budget);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SmsSetupScreen()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Header
              Text(
                "Welcome to Dabbu",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Your personal finance companion.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Feature Grid (Bento Style)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        context,
                        icon: Icons.auto_awesome,
                        title: "Smart Tracking",
                        subtitle: "Auto-detects bills & expenses.",
                        color: Colors.purple.shade50,
                        iconColor: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeatureCard(
                        context,
                        icon: Icons.pie_chart_rounded,
                        title: "Visual Insights",
                        subtitle: "Clear charts, no clutter.",
                        color: Colors.blue.shade50,
                        iconColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildFeatureCard(
                context,
                icon: Icons.shield_outlined,
                title: "Privacy First",
                subtitle: "Your data stays on your device. Always.",
                color: Colors.green.shade50,
                iconColor: Colors.green,
              ),

              const SizedBox(height: 40),

              // Input Section
              Text(
                "Let's get you set up",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: CMS.setup['name_label']!,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Monthly Budget (Optional)",
                  hintText: "e.g. 50000",
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  prefixText: CMS.common['currency_symbol'],
                ),
              ),

              const SizedBox(height: 32),

              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, child) {
                  return FilledButton(
                    onPressed: _viewModel.isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _viewModel.isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(CMS.setup['next_step']!),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
  }) {
    // Determine responsive theme colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Theme.of(context).cardColor : color;
    // For dark mode, use primary color for icon if possible, or keep specific color

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border:
            isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.05))
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
