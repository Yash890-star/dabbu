import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../services/backup_service.dart';
import '../services/background_service.dart'; // Added for immediate registration
import '../viewmodels/initial_setup_view_model.dart';
import '../viewmodels/sms_setup_view_model.dart';
import 'main_screen.dart';

import '../widgets/common/app_button.dart';
import '../widgets/common/custom_input.dart';
import '../widgets/common/step_indicator.dart';
import '../widgets/fade_in_entry.dart';
import 'teach_pattern_screen.dart'; // Added

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final PageController _pageController = PageController();
  final InitialSetupViewModel _setupViewModel = InitialSetupViewModel();
  final SmsSetupViewModel _smsViewModel = SmsSetupViewModel();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  int _currentStep = 0;
  bool _isSyncing = false;
  int _syncedCount = 0;
  List<dynamic> _syncedMessages =
      []; // Use dynamic to avoid import if needed, but imported

  @override
  void dispose() {
    _pageController.dispose();
    _setupViewModel.dispose();
    _smsViewModel.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  bool _featureAutoSync = true;
  bool _notificationPermissionGranted = false;

  void _nextPage() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      // Finish
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  Future<void> _submitStep1() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(CMS.setup['name_error']!),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final budgetStr = _budgetController.text.trim();
    final double? budget =
        budgetStr.isNotEmpty ? double.tryParse(budgetStr) : null;

    setState(() => _isSyncing = true); // Reusing loading flag
    await _setupViewModel.saveUserData(name, budget: budget);
    if (!mounted) return;
    setState(() => _isSyncing = false);

    _nextPage();
  }

  Future<void> _startSync() async {
    setState(() => _isSyncing = true);

    // This handles SMS Permission + Inbox Scan
    final messages = await _smsViewModel.scanInbox();

    if (!mounted) return;
    setState(() => _isSyncing = false);

    if (messages != null) {
      _syncedCount = messages.length;
      setState(() {
        _syncedMessages = messages;
      });
      // Move to Next (Education/Training)
      _nextPage();
    } else {
      // Error handling (keep existing)
      if (_smsViewModel.permissionDeniedPermanently) {
        if (mounted) _showSettingsDialog();
      } else if (_smsViewModel.errorMessage != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_smsViewModel.errorMessage!)));
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

  void _launchTeachForSender(String sender) async {
    dynamic targetMsg;
    for (var msg in _syncedMessages) {
      try {
        if (msg.address == sender) {
          targetMsg = msg;
          break;
        }
      } catch (e) {
        // ignore
      }
    }

    if (targetMsg != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeachPatternScreen(message: targetMsg),
        ),
      );
      setState(() {});
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not find original message.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                StepIndicator(currentStep: _currentStep, totalSteps: 6),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep0Intro(),
                      _buildStep1Input(),
                      _buildStep2Sms(),
                      _buildStep3Notifications(),
                      _buildStep4Training(),
                      _buildStep5Success(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_currentStep == 1)
            Positioned(
              top: 40,
              right: 16,
              child: TextButton.icon(
                onPressed: () async {
                  // ... (keep backup logic)
                  final success = await BackupService.instance.importSettings(
                    context,
                  );
                  if (!context.mounted) return;
                  if (success) {
                    // ...
                    final prefs = await SharedPreferences.getInstance();
                    final b = prefs.getDouble('monthly_budget');
                    if (b != null && b > 0) {
                      _budgetController.text = b.toStringAsFixed(0);
                    }
                  }
                },
                icon: const Icon(Icons.download_for_offline),
                label: const Text("Import Backup"),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ... (keep _buildStep0Intro, _buildStep1Input)

  Widget _buildStep0Intro() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                FadeInEntry(
                  delay: 100,
                  child: Text(
                    "Control your Money",
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),

                // Bento Grid
                FadeInEntry(
                  delay: 200,
                  child: SizedBox(
                    height: 280, // Fixed height for the grid
                    child: Row(
                      children: [
                        // Large Left Card (Auto Sync)
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.sync_outlined,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  "Auto\nSync",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tracks SMS automatically",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right Column (Two Small Cards)
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              // Top Right (Privacy)
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.teal.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        color: Colors.teal,
                                        size: 28,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Privacy\nFirst",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Bottom Right (Offline)
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.orange.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.wifi_off,
                                        color: Colors.orange,
                                        size: 28,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "Works\nOffline",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FadeInEntry(
                  delay: 300,
                  child: AppButton(label: "Get Started", onPressed: _nextPage),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1Input() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              MediaQuery.of(context).size.height -
              200, // Approximate safe height
        ),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              FadeInEntry(
                delay: 100,
                child: Text(
                  "Welcome to Dabbu",
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeInEntry(
                delay: 200,
                child: Text(
                  "Let's personalize your experience.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeInEntry(
                delay: 300,
                child: CustomInput(
                  label: CMS.setup['name_label']!,
                  hint: "e.g. John Doe",
                  controller: _nameController,
                  prefixIcon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 24),
              FadeInEntry(
                delay: 400,
                child: CustomInput(
                  label: "Monthly Budget (Optional)",
                  hint: "e.g. 50000",
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 24),
              FadeInEntry(
                delay: 500,
                child: AppButton(
                  label: "Continue",
                  onPressed: _isSyncing ? null : _submitStep1,
                  isLoading: _isSyncing,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2Sms() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                FadeInEntry(
                  delay: 100,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.sms_outlined,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInEntry(
                  delay: 150,
                  child: Text(
                    "Sync Messages",
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FadeInEntry(
                  delay: 200,
                  child: Text(
                    "Allow Dabbu to read SMS to track your expenses automatically. We only look for bank transactions.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInEntry(
                  delay: 250,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Sync History From:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 32),
                        InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _smsViewModel.selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (BuildContext context, Widget? child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(
                                      context,
                                    ).colorScheme.copyWith(
                                      primary: AppColors.primary,
                                      onPrimary: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null &&
                                picked != _smsViewModel.selectedDate) {
                              setState(() {
                                _smsViewModel.setSelectedDate(picked);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 24),
                                Text(
                                  "${_smsViewModel.selectedDate.day}/${_smsViewModel.selectedDate.month}/${_smsViewModel.selectedDate.year}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_isSyncing) ...[
                  const Spacer(),
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text("Scanning your inbox..."),
                    ],
                  ),
                  const Spacer(),
                ] else ...[
                  const Spacer(),
                  FadeInEntry(
                    delay: 300,
                    child: AppButton(
                      label: "Allow & Sync",
                      onPressed: _startSync,
                      isLoading: _isSyncing,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _nextPage,
                    child: const Text("Skip SMS setup"),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep3Notifications() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                FadeInEntry(
                  delay: 100,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      size: 48,
                      color: Colors.amber,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeInEntry(
                  delay: 150,
                  child: Text(
                    "Stay Updated",
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FadeInEntry(
                  delay: 200,
                  child: Text(
                    "Enable notifications to get instant alerts when Dabbu detects a new transaction.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeInEntry(
                  delay: 250,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sync, color: AppColors.primary),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Background Auto-Sync",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Check for new SMS periodically",
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _featureAutoSync,
                          onChanged: (val) {
                            setState(() => _featureAutoSync = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FadeInEntry(
                  delay: 300,
                  child: AppButton(
                    label: "Enable Notifications",
                    onPressed: _requestNotification,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _nextPage,
                  child: const Text("Maybe Later"),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestNotification() async {
    try {
      // Use custom channel to avoid Request Code 24 conflict with another_telephony
      const platform = MethodChannel('com.example.dabbu/permissions');
      final bool granted = await platform.invokeMethod(
        'requestNotificationPermission',
      );

      // Update UI state
      setState(() {
        _notificationPermissionGranted = granted;
      });

      if (granted && _featureAutoSync) {
        // Just move next if granted
        _nextPage();
      } else if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notifications disabled. You can enable them later."),
          ),
        );
        _nextPage();
      } else {
        _nextPage();
      }
    } catch (e) {
      debugPrint("Error requesting notification: $e");
      // Fallback or just proceed
      _nextPage();
    }
  }

  Widget _buildStep4Training() {
    final senders = _smsViewModel.potentialSenders;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          FadeInEntry(
            delay: 100,
            child: Text(
              "Teach Dabbu",
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          FadeInEntry(
            delay: 150,
            child: Text(
              "Found ${senders.length} senders in your history.",
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                senders.isEmpty
                    ? const Center(
                      child: Text(
                        "No messages found.",
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                    : ListView.builder(
                      itemCount: senders.length,
                      itemBuilder: (context, index) {
                        final sender = senders[index];
                        return Card(
                          color: Theme.of(context).cardColor,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.1,
                              ),
                              child: Text(
                                sender.substring(0, 1),
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                            title: Text(
                              sender,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text("Tap to train"),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _launchTeachForSender(sender);
                            },
                          ),
                        );
                      },
                    ),
          ),
          AppButton(
            label: "Finish Setup",
            onPressed: () {
              // Save AutoSync preference if we haven't already
              // Actually, we should probably save it to SharedPreferences
              SharedPreferences.getInstance().then((prefs) async {
                // Use 'bg_sync_enabled' to match NotificationSettingsScreen
                await prefs.setBool('bg_sync_enabled', _featureAutoSync);
                if (_featureAutoSync) {
                  await BackgroundService().registerPeriodicTask();
                }
              });
              _nextPage();
            },
            type: AppButtonType.primary,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStep5Success() {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(
                  Icons.check_circle_outline,
                  size: 100,
                  color: AppColors.success,
                ),
                const SizedBox(height: 24),
                Text(
                  "All Set!",
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _syncedCount > 0
                      ? "We found $_syncedCount transactions."
                      : "You're ready to start tracking.",
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                AppButton(
                  label: "Go to Dashboard",
                  onPressed: () {
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setBool('initialSetupDone', true);
                    });
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(),
                      ),
                    );
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
