import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Explicitly used now
import 'package:another_telephony/telephony.dart';
import 'package:intl/intl.dart';

import 'sms_list_screen.dart';

class SmsSetupScreen extends StatefulWidget {
  const SmsSetupScreen({super.key});

  @override
  State<SmsSetupScreen> createState() => _SmsSetupScreenState();
}

class _SmsSetupScreenState extends State<SmsSetupScreen> {
  final Telephony _telephony = Telephony.instance;
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 30));
  bool _isLoading = false;

  Future<void> _fetchSmsAndContinue() async {
    setState(() => _isLoading = true);

    // 1. Request Permission using permission_handler
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Show dialog guiding them to settings if permanently denied
        if (status.isPermanentlyDenied) {
          _showSettingsDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permission is required to find transactions.'),
            ),
          );
        }
      }
      return;
    }

    try {
      // 2. Fetch Messages
      // using getInboxSms from another_telephony
      List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // 3. Filter by Date in Dart
      final int filterTimestamp = _selectedDate.millisecondsSinceEpoch;

      final recentMessages =
          messages.where((msg) {
            final msgDate = msg.date ?? 0;
            return msgDate >= filterTimestamp;
          }).toList();

      if (!mounted) return;

      if (recentMessages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No messages found after ${DateFormat.yMMMd().format(_selectedDate)}',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 4. Navigate to List
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmsListScreen(messages: recentMessages),
        ),
      );
    } catch (e) {
      debugPrint("Error fetching SMS: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Permission Required"),
            content: const Text(
              "SMS permission is permanently denied. Please enable it in app settings to use this feature.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text("Open Settings"),
              ),
            ],
          ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Tracking")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.sms_failed_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              "Scan for Transactions",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "We will scan your inbox to find bank messages. Select how far back we should look.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                "Start from: ${DateFormat.yMMMd().format(_selectedDate)}",
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: _isLoading ? null : _fetchSmsAndContinue,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Text("Scan Inbox"),
            ),
          ],
        ),
      ),
    );
  }
}
