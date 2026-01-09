import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS/macOS settings (if needed in future)
    final fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
          requestSoundPermission: false,
          requestBadgePermission: false,
          requestAlertPermission: false,
        );

    final fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
        fln.NotificationResponse response,
      ) async {
        // Handle notification tap
        debugPrint("Notification Tapped: ${response.payload}");
      },
    );

    _isInitialized = true;
  }

  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                fln.AndroidFlutterLocalNotificationsPlugin
              >();

      final bool? granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; // iOS permissions are requested on init or separate call
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const fln.AndroidNotificationDetails androidPlatformChannelSpecifics =
        fln.AndroidNotificationDetails(
          'dabbu_general_channel',
          'General Notifications',
          channelDescription: 'General app notifications',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          ticker: 'ticker',
        );
    const fln.NotificationDetails platformChannelSpecifics =
        fln.NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> scheduleTallyReminder({
    required int hour,
    required int minute,
  }) async {
    await flutterLocalNotificationsPlugin.cancel(1001); // ID for Tally Reminder

    await flutterLocalNotificationsPlugin.zonedSchedule(
      1001,
      'Time to Tally!',
      'It\'s strictly time to check your bank balance and tally up. Catch those leaks!',
      _nextInstanceOf(hour, minute),
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'dabbu_tally_channel',
          'Tally Reminders',
          channelDescription: 'Reminders to tally your balance',
        ),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: fln.DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> checkBudgetThresholds({int? specificCategoryId}) async {
    final prefs = await SharedPreferences.getInstance();
    final bool alertsEnabled = prefs.getBool('budget_alerts_enabled') ?? true;

    if (!alertsEnabled) return;

    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    // 1. Check Global Budget
    final double monthlyBudget = prefs.getDouble('monthly_budget') ?? 0.0;
    if (monthlyBudget > 0) {
      final summary = await DatabaseHelper.instance.getMonthlySummary(
        month,
        year,
      );
      final expense = summary['expense'] ?? 0.0;
      await _processThreshold(
        idSuffix: 'global',
        title: 'Monthly Budget',
        budget: monthlyBudget,
        spent: expense,
        month: month,
        year: year,
      );
    }

    // 2. Check Category Budget (if specificCategoryId is provided, only check that)
    final categories = await DatabaseHelper.instance.getCategories();
    for (var cat in categories) {
      final int catId = cat['id'] as int;
      if (specificCategoryId != null && catId != specificCategoryId) continue;

      final double catBudget = (cat['budgetLimit'] as num?)?.toDouble() ?? 0.0;
      if (catBudget > 0) {
        final double catSpend = await DatabaseHelper.instance.getCategorySpend(
          month,
          year,
          catId,
        );
        await _processThreshold(
          idSuffix: 'cat_$catId',
          title: '${cat['name']} Budget',
          budget: catBudget,
          spent: catSpend,
          month: month,
          year: year,
        );
      }
    }
  }

  Future<void> _processThreshold({
    required String idSuffix,
    required String title,
    required double budget,
    required double spent,
    required int month,
    required int year,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key100 = 'alert_100_${idSuffix}_${month}_$year';
    final key90 = 'alert_90_${idSuffix}_${month}_$year';

    final bool alerted100 = prefs.getBool(key100) ?? false;
    final bool alerted90 = prefs.getBool(key90) ?? false;

    final double percentage = (spent / budget) * 100;

    // debugPrint("Checking Budget: $title ($percentage%)");

    if (percentage >= 100) {
      if (!alerted100) {
        await showInstantNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: "Alert: $title Exceeded!",
          body:
              "You've spent ${(percentage).toStringAsFixed(1)}% of your limit.",
        );
        await prefs.setBool(key100, true);
        await prefs.setBool(key90, true); // Implicitly warned
      }
    } else if (percentage >= 90) {
      if (!alerted90) {
        await showInstantNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: "Warning: Approaching Limit",
          body:
              "You've used ${(percentage).toStringAsFixed(1)}% of your $title.",
        );
        await prefs.setBool(key90, true);
      }
      // If we dropped below 100 (e.g. deleted transaction), reset 100 flag
      if (alerted100) {
        await prefs.setBool(key100, false);
      }
    } else {
      // Below 90, reset all
      if (alerted90) await prefs.setBool(key90, false);
      if (alerted100) await prefs.setBool(key100, false);
    }
  }
}
