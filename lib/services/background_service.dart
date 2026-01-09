import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'message_helper.dart';
import 'notification_service.dart';

const String simplePeriodicTask = "simplePeriodicTask";
const String periodicSmsSyncTask = "periodicSmsSync";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint("Native called background task: $task");

    if (task == periodicSmsSyncTask) {
      try {
        debugPrint("Background Service: Starting SMS Sync...");

        // 1. Initialize Dependencies
        // NotificationService might need initialization if we plan to show notifications here
        final notificationService = NotificationService();
        await notificationService.init();

        // 2. Run Sync
        final messageHelper = MessageHelper();
        // Look back 1 day mostly, to be efficient.
        // If the task runs every 15 mins, 1 day is plenty of buffer.
        int newCount = await messageHelper.processNewMessages(lookBackDays: 1);

        debugPrint(
          "Background Service: Sync found $newCount new transactions.",
        );

        // 3. Notify User if new items found
        if (newCount > 0) {
          await notificationService.showInstantNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: 'New Transactions Found',
            body:
                'Dabbu found $newCount new transaction${newCount > 1 ? 's' : ''}.',
            payload: 'new_transaction_sync',
          );

          // 4. Check Budget Alerts
          await notificationService.checkBudgetThresholds();
        }
      } catch (e) {
        debugPrint("Background Service Error: $e");
        return Future.value(false);
      }
    }

    return Future.value(true);
  });
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      // isInDebugMode: true, // Deprecated, use logging if needed
    );
    debugPrint("Background Service Initialized");
  }

  Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "1", // Unique Name
      periodicSmsSyncTask,
      frequency: const Duration(minutes: 15), // Minimum 15 mins
      constraints: Constraints(requiresBatteryNotLow: true),
      initialDelay: const Duration(seconds: 10),
      // Use cancelAndReenqueue to ensure fresh registration
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
    debugPrint("Periodic Task Registered: $periodicSmsSyncTask");
  }

  Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}
