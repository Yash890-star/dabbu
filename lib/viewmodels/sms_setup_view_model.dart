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

  // New State for Analysis
  List<String> potentialSenders = [];

  /// Returns a list of messages if successful, or null if failed/denied.
  Future<List<SmsMessage>?> scanInbox() async {
    isLoading = true;
    errorMessage = null;
    permissionDeniedPermanently = false;
    notifyListeners();

    try {
      // 1. Check current status
      var status = await Permission.sms.status;
      if (status.isPermanentlyDenied) {
        permissionDeniedPermanently = true;
        isLoading = false;
        notifyListeners();
        return null;
      }

      // 2. Request SMS Permission via Plugin
      // We use the plugin's own request to avoid MethodChannel "Reply already submitted" crash
      bool? granted = await _telephony.requestPhoneAndSmsPermissions;

      if (granted != true) {
        // Double check status to see if it just got permanently denied
        status = await Permission.sms.status;
        if (status.isPermanentlyDenied) {
          permissionDeniedPermanently = true;
        } else {
          errorMessage = "Permission required";
        }
        isLoading = false;
        notifyListeners();
        return null;
      }

      // 3. Save Date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('smsStartDate', selectedDate.millisecondsSinceEpoch);

      // 4. Fetch
      List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // 5. Filter
      final int filterTimestamp = selectedDate.millisecondsSinceEpoch;
      final recentMessages =
          messages.where((msg) {
            final msgDate = msg.date ?? 0;
            return msgDate >= filterTimestamp;
          }).toList();

      // 6. Analyze Senders
      await _analyzeSenders(recentMessages);

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

  Future<void> _analyzeSenders(List<SmsMessage> messages) async {
    // Group all senders by message count
    final Map<String, int> counts = {};
    for (var m in messages) {
      final addr = m.address ?? "Unknown";
      counts[addr] = (counts[addr] ?? 0) + 1;
    }

    // Sort by count
    final sorted =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Expose all senders (or top 50 to avoid crazy lists, but user asked for "show all")
    // We'll return just the names for the list
    potentialSenders = sorted.map((e) => e.key).toList();
  }
}
