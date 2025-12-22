import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class MessageHelper {
  final Telephony _telephony = Telephony.instance;

  // Modified to allow looking back X days
  Future<int> processNewMessages({int lookBackDays = 60}) async {
    final prefs = await SharedPreferences.getInstance();
    final dbHelper = DatabaseHelper.instance;

    debugPrint("--- STARTING SYNC ---");

    // 1. Fetch all patterns
    final patterns = await dbHelper.database.then((db) => db.query('patterns'));
    if (patterns.isEmpty) {
      debugPrint("No patterns found in DB.");
      return 0;
    }

    // 2. Calculate the Look-back Date
    // We want to scan messages from [Today - lookBackDays]
    final DateTime sinceDate = DateTime.now().subtract(
      Duration(days: lookBackDays),
    );
    final int sinceTimestamp = sinceDate.millisecondsSinceEpoch;

    // 3. Fetch Inbox (Filtered by Date in Dart for reliability)
    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    int newTransactionsCount = 0;

    // 4. Iterate through messages
    for (var msg in messages) {
      final msgDate = msg.date ?? 0;

      // STOP if the message is too old (older than our lookback window)
      if (msgDate < sinceTimestamp) {
        debugPrint(
          "Stopping scan: Message date ${DateTime.fromMillisecondsSinceEpoch(msgDate)} is older than lookback limit.",
        );
        break;
      }

      final body = msg.body ?? "";
      final msgAddress = (msg.address ?? "").toUpperCase();

      // Find patterns matching this Sender ID
      final applicablePatterns =
          patterns.where((p) {
            final patternSenderId = (p['senderId'] as String).toUpperCase();
            return msgAddress.toUpperCase().contains(patternSenderId);
          }).toList();
      for (var pattern in applicablePatterns) {
        final regexString = pattern['patternRegex'] as String;

        try {
          final regExp = RegExp(regexString, caseSensitive: false);
          final match = regExp.firstMatch(body);

          if (match != null) {
            // String rawAmount = match.group(1) ?? "0";
            // rawAmount = rawAmount.replaceAll(RegExp(r'[^0-9.]'), '');
            // double amount = double.tryParse(rawAmount) ?? 0.0;

            // 1. Get the raw string (e.g. "Rs.409.00")
            String rawString = match.group(1) ?? "0";

            // 2. Cleanup: Remove commas (common in currency like 1,000)
            String cleanString = rawString.replaceAll(',', '');

            // 3. Smart Extraction: Find the first valid number (e.g. "409.00" inside ".409.00")
            // This regex looks for: Digits + Optional (Dot + Digits)
            RegExp numberRegex = RegExp(r'(\d+)(\.\d+)?');
            Match? numMatch = numberRegex.firstMatch(cleanString);

            double amount = 0.0;
            if (numMatch != null) {
              // If we found a valid number pattern, parse THAT.
              amount = double.tryParse(numMatch.group(0) ?? "0") ?? 0.0;
            }
            // CRITICAL CHECK: Does this exact transaction already exist?
            final isDuplicate = await _checkForDuplicate(
              msg.address ?? "",
              amount,
              msgDate,
            );

            if (!isDuplicate) {
              debugPrint("Found NEW Transaction: $amount from ${msg.address}");
              await dbHelper.insertTransaction({
                'amount': amount,
                'sender': msg.address,
                'body': body,
                'date': msgDate,
                'type': pattern['messageType'],
                'categoryId': 1,
                'patternId': pattern['id'],
              });
              newTransactionsCount++;
            } else {
              // debugPrint("Duplicate ignored: $amount");
            }

            // Match found for this SMS, stop trying other patterns
            break;
          } else {
            debugPrint("--- Messages $regExp msg.body: ${msg.body}---");
          }
        } catch (e) {
          debugPrint("Regex Error for ${pattern['name']}: $e");
        }
      }
    }

    // Update sync time (optional now, mostly for reference)
    await prefs.setInt(
      'lastSmsSyncTime',
      DateTime.now().millisecondsSinceEpoch,
    );

    debugPrint("--- SYNC COMPLETE: Added $newTransactionsCount new items ---");
    return newTransactionsCount;
  }

  Future<bool> _checkForDuplicate(
    String sender,
    double amount,
    int date,
  ) async {
    final db = await DatabaseHelper.instance.database;
    // Check for same sender, same amount, and same timestamp (msgDate is very precise)
    final result = await db.query(
      'transactions',
      where: 'sender = ? AND amount = ? AND date = ?',
      whereArgs: [sender, amount, date],
    );
    return result.isNotEmpty;
  }
}
