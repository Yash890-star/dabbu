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
  final InitialSetupViewModel _viewModel = InitialSetupViewModel();

  Future<void> _submitName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(CMS.setup['name_error']!)));
      return;
    }

    await _viewModel.saveName(name);

    if (!mounted) return;

    // Navigate to SMS Setup (We don't go to Home yet)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SmsSetupScreen()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white, // Removed to use Theme background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                CMS.setup['welcome']!,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                CMS.setup['ask_name']!,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: CMS.setup['name_label']!,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, child) {
                  return ElevatedButton(
                    onPressed: _viewModel.isLoading ? null : _submitName,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _viewModel.isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
}
