import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../viewmodels/sms_setup_view_model.dart';
import 'sms_list_screen.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/glass_card.dart';
import '../widgets/fade_in_entry.dart';

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
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        Navigator.pushReplacement(
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
            SnackBar(
              content: Text(CMS.smsSetup['permission_required']!),
              backgroundColor: AppColors.error,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${CMS.smsSetup['error_prefix']!}${_viewModel.errorMessage}',
              ),
              backgroundColor: AppColors.error,
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
            backgroundColor: Theme.of(context).cardColor,
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _viewModel.selectedDate) {
      _viewModel.setSelectedDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(CMS.smsSetup['title']!), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              FadeInEntry(
                delay: 100,
                child: Text(
                  CMS.smsSetup['scan_title']!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              FadeInEntry(
                delay: 200,
                child: Text(
                  CMS.smsSetup['scan_subtitle']!,
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Info Card
              FadeInEntry(
                delay: 300,
                child: GlassCard(
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search,
                          size: 30,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Scan History",
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Analyze past messages to find untracked transactions or train new patterns.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Date Picker
              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, child) {
                  return FadeInEntry(
                    delay: 400,
                    child: GlassCard(
                      onTap: _pickDate,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
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
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
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
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              AnimatedBuilder(
                animation: _viewModel,
                builder: (context, child) {
                  return FadeInEntry(
                    delay: 500,
                    child: AppButton(
                      onPressed:
                          _viewModel.isLoading ? null : _fetchSmsAndContinue,
                      isLoading: _viewModel.isLoading,
                      label: CMS.smsSetup['scan_btn']!,
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
