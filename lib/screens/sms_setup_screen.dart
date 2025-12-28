import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../viewmodels/sms_setup_view_model.dart';
import 'sms_list_screen.dart';
import '../widgets/app_card.dart';

class SmsSetupScreen extends StatefulWidget {
  const SmsSetupScreen({super.key});

  @override
  State<SmsSetupScreen> createState() => _SmsSetupScreenState();
}

class _SmsSetupScreenState extends State<SmsSetupScreen> {
  final SmsSetupViewModel _viewModel = SmsSetupViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _fetchSmsAndContinue() async {
    final messages = await _viewModel.scanInbox();

    if (!mounted) return;

    if (messages != null) {
      if (messages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${CMS.smsSetup['no_messages']!}${DateFormat.yMMMd().format(_viewModel.selectedDate)}',
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmsListScreen(messages: messages),
          ),
        );
      }
    } else {
      if (_viewModel.permissionDeniedPermanently) {
        _showSettingsDialog();
      } else if (_viewModel.errorMessage != null) {
        if (_viewModel.errorMessage == "Permission required") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(CMS.smsSetup['permission_required']!)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${CMS.smsSetup['error_prefix']!}${_viewModel.errorMessage}',
              ),
            ),
          );
        }
      }
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.smsSetup['perm_denied_title']!),
            content: Text(CMS.smsSetup['perm_denied_content']!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(CMS.common['cancel']!),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: Text(CMS.smsSetup['open_settings']!),
              ),
            ],
          ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _viewModel.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _viewModel.selectedDate) {
      _viewModel.setSelectedDate(picked);
    }
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
              Text(
                CMS.smsSetup['scan_title']!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                CMS.smsSetup['scan_subtitle']!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Info Card using Bento Style
              AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.sms_failed_outlined,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Why scan SMS?",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Dabbu analyzes bank SMS to clear the clutter and track expenses automatically. No manual entry needed.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Date Picker Bento Block
              // Date Picker Bento Block
              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, child) {
                  return AppCard(
                    onTap: _pickDate,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                CMS.smsSetup['start_from']!,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                DateFormat.yMMMd().format(
                                  _viewModel.selectedDate,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, child) {
                  return FilledButton.icon(
                    onPressed:
                        _viewModel.isLoading ? null : _fetchSmsAndContinue,
                    icon:
                        _viewModel.isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.search),
                    label: Text(CMS.smsSetup['scan_btn']!),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
