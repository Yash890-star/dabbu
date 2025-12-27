import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SmsSetupViewModel extends ChangeNotifier {
  // --- State ---
  DateTime selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool isLoading = false;

  // Status flags for UI
  bool permissionDeniedPermanently = false;
  String? errorMessage;

  final Telephony _telephony = Telephony.instance;

  // --- Actions ---

  void setSelectedDate(DateTime date) {
    selectedDate = date;
    notifyListeners();
  }

  /// Returns a list of messages if successful, or null if failed/denied.
  Future<List<SmsMessage>?> scanInbox() async {
    isLoading = true;
    errorMessage = null;
    permissionDeniedPermanently = false;
    notifyListeners();

    try {
      // 1. Request Permission
      var status = await Permission.sms.status;
      if (!status.isGranted) {
        status = await Permission.sms.request();
      }

      if (!status.isGranted) {
        isLoading = false;
        if (status.isPermanentlyDenied) {
          permissionDeniedPermanently = true;
        } else {
          errorMessage =
              "Permission required"; // Key handled in UI usually, but internal flag here
        }
        notifyListeners();
        return null; // Stop
      }

      // 2. Save Date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('smsStartDate', selectedDate.millisecondsSinceEpoch);

      // 3. Fetch
      List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // 4. Filter
      final int filterTimestamp = selectedDate.millisecondsSinceEpoch;
      final recentMessages =
          messages.where((msg) {
            final msgDate = msg.date ?? 0;
            return msgDate >= filterTimestamp;
          }).toList();

      isLoading = false;
      notifyListeners();
      return recentMessages;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
