import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool? _notificationsEnabled;
  bool _tallyReminderEnabled = true; // In real app, load from prefs
  bool _bgSyncEnabled = false;
  bool _budgetAlertsEnabled = true; // New Toggle
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkPermissions();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bgSyncEnabled = prefs.getBool('bg_sync_enabled') ?? false;
      _budgetAlertsEnabled = prefs.getBool('budget_alerts_enabled') ?? true;
    });
  }

  Future<void> _toggleBudgetAlerts(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _budgetAlertsEnabled = val);
    await prefs.setBool('budget_alerts_enabled', val);
  }

  Future<void> _toggleBgSync(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _bgSyncEnabled = val);
    await prefs.setBool('bg_sync_enabled', val);

    if (val) {
      await BackgroundService().registerPeriodicTask();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Background Sync Enabled (Every 15 mins)"),
          ),
        );
      }
    } else {
      await BackgroundService().cancelAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Background Sync Disabled")),
        );
      }
    }
  }

  Future<void> _checkPermissions() async {
    // We can't easily check 'is granted' without requesting on Android < 13 or using permission_handler
    // But for now let's just assume if we can request, we will.
    // In a polished app, use Permission.notification.status
  }

  Future<void> _requestPermissions() async {
    final granted = await NotificationService().requestPermissions();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = granted;
    });
    if (granted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Permissions granted!")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Permission denied. Check system settings."),
        ),
      );
    }
  }

  Future<void> _requestBatteryexempt() async {
    var status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      status = await Permission.ignoreBatteryOptimizations.request();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Battery Optimization Status: ${status.name}"),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Already unrestricted!")));
      }
    }
  }

  Future<void> _testNotification() async {
    await NotificationService().showInstantNotification(
      id: 0,
      title: "Test Notification",
      body: "This is a test alert from Dabbu!",
    );
  }

  Future<void> _updateSchedule() async {
    if (_tallyReminderEnabled) {
      await NotificationService().scheduleTallyReminder(
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Reminder scheduled for ${_reminderTime.format(context)} daily",
            ),
          ),
        );
      }
    } else {
      await NotificationService().cancelAll(); // Or cancel specific ID
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Permission Status
          Card(
            child: ListTile(
              leading: const Icon(Icons.security),
              title: const Text("System Permissions"),
              subtitle:
                  _notificationsEnabled == true
                      ? const Text(
                        "Granted",
                        style: TextStyle(color: Colors.green),
                      )
                      : const Text("Not Granted / Unknown"),
              trailing:
                  _notificationsEnabled == true
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                        onPressed: _requestPermissions,
                        child: const Text("Request"),
                      ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Tally Reminder
          Text(
            "Tally Reminders",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Daily Reminder"),
                  subtitle: const Text("Remind me to check my balance"),
                  value: _tallyReminderEnabled,
                  onChanged: (val) {
                    setState(() => _tallyReminderEnabled = val);
                    _updateSchedule();
                  },
                ),
                ListTile(
                  title: const Text("Reminder Time"),
                  trailing: Text(
                    _reminderTime.format(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _reminderTime,
                    );
                    if (time != null) {
                      setState(() => _reminderTime = time);
                      _updateSchedule();
                    }
                  },
                ),
              ],
            ),
          ),

          // 3. Background Sync
          Text(
            "Background Sync",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text("Auto-Scan SMS"),
              subtitle: const Text("Periodically check for new transactions"),
              value: _bgSyncEnabled,
              onChanged: _toggleBgSync,
            ),
          ),

          if (_bgSyncEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Card(
                color: const Color(0xFFFFF3CD), // Warning/Info color
                child: ListTile(
                  leading: const Icon(
                    Icons.battery_alert,
                    color: Colors.orange,
                  ),
                  title: const Text("Improve Reliability"),
                  subtitle: const Text("Prevent system from delaying scans"),
                  trailing: TextButton(
                    onPressed: _requestBatteryexempt,
                    child: const Text("OPTIMIZE"),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // 3.5 Budget Alerts
          Text("Budget Alerts", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text("Spending Alerts"),
              subtitle: const Text("Notify when exceeding budget (90% / 100%)"),
              value: _budgetAlertsEnabled,
              onChanged: _toggleBudgetAlerts,
            ),
          ),

          const SizedBox(height: 20),

          // 3. Test
          ElevatedButton.icon(
            onPressed: _testNotification,
            icon: const Icon(Icons.notifications_active),
            label: const Text("Send Test Notification"),
          ),
        ],
      ),
    );
  }
}
