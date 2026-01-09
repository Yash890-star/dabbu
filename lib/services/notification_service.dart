import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
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
    try {
      final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      // Handle flutter_timezone 5.x which returns TimezoneInfo object
      String timeZoneName;
      if (timeZoneInfo is String) {
        timeZoneName = timeZoneInfo;
      } else {
        // Assume has identifier property based on search results
        try {
          timeZoneName = (timeZoneInfo as dynamic).identifier;
        } catch (e) {
          timeZoneName = timeZoneInfo.toString();
        }
      }
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint(
        "Could not set local timezone. Defaulting to UTC/Default. Error: $e",
      );
    }

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

    // Create Channel explicitly for Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                fln.AndroidFlutterLocalNotificationsPlugin
              >();

      const fln.AndroidNotificationChannel tallyChannel =
          fln.AndroidNotificationChannel(
            'dabbu_tally_channel_v2',
            'Tally Reminders',
            description: 'Reminders to tally your balance',
            importance: fln.Importance.max,
            playSound: true,
          );

      await androidImplementation?.createNotificationChannel(tallyChannel);
    }

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
          'dabbu_tally_channel_v2', // Use the SAME channel as reminder
          'Tally Reminders',
          channelDescription: 'Reminders to tally your balance',
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
          'dabbu_tally_channel_v2',
          'Tally Reminders',
          channelDescription: 'Reminders to tally your balance',
        ),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: fln.DateTimeComponents.time,
    );
    // Save scheduled time for debugging
    final nextTime = _nextInstanceOf(hour, minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_scheduled_rem_time',
      nextTime.toIso8601String(),
    );

    debugPrint("Scheduled Tally Reminder for: $nextTime");
  }

  Future<void> scheduleOneMinuteTest() async {
    // 1. Get current time in UTC directly
    final DateTime nowUTC = DateTime.now().toUtc();
    final DateTime scheduledUTC = nowUTC.add(const Duration(minutes: 1));

    // 2. Use tz.UTC location explicitly
    final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(scheduledUTC, tz.UTC);

    debugPrint("Scheduling 1-min test for UTC: $scheduledTZ");

    await flutterLocalNotificationsPlugin.zonedSchedule(
      1002,
      '1 Minute Test (UTC)',
      'If you see this, UTC Scheduling works!',
      scheduledTZ,
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'dabbu_tally_channel_v2',
          'Tally Reminders',
          channelDescription: 'Reminders to tally your balance',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          playSound: true,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
    );
    // Save scheduled time for debugging
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_scheduled_rem_time',
      scheduledTZ.toIso8601String(),
    );
  }

  Future<List<fln.PendingNotificationRequest>> getPendingNotifications() async {
    return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    // 1. Get current time in Native Local (device time)
    final DateTime now = DateTime.now();

    // 2. Create the target time in Native Local
    DateTime scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // 3. If passed, add a day
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 4. Safely convert Native Local -> configured tz.local
    // If tz.local is UTC, this converts 22:00 IST -> 16:30 UTC (Correct absolute time)
    // If tz.local is IST, this converts 22:00 IST -> 22:00 IST (Correct absolute time)
    return tz.TZDateTime.from(scheduledDate, tz.local);
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
