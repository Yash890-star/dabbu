import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../viewmodels/sms_setup_view_model.dart';
import 'sms_list_screen.dart';

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
        // Success: Navigate
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmsListScreen(messages: messages),
          ),
        );
      }
    } else {
      // Failed or Denied
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
      appBar: AppBar(title: Text(CMS.smsSetup['title']!)),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.sms_failed_outlined,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),
                Text(
                  CMS.smsSetup['scan_title']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  CMS.smsSetup['scan_subtitle']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),

                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    "${CMS.smsSetup['start_from']!}${DateFormat.yMMMd().format(_viewModel.selectedDate)}",
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),

                const Spacer(),

                ElevatedButton(
                  onPressed: _viewModel.isLoading ? null : _fetchSmsAndContinue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child:
                      _viewModel.isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(CMS.smsSetup['scan_btn']!),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
