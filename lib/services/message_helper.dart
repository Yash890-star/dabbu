import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class MessageHelper {
  final Telephony _telephony = Telephony.instance;

  // Modified to allow looking back X days and forcing full scan
  Future<int> processNewMessages({
    int lookBackDays = 60,
    bool forceFullScan = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dbHelper = DatabaseHelper.instance;

    debugPrint("--- STARTING SYNC (Force Full: $forceFullScan) ---");

    // 1. Fetch all patterns
    final patterns = await dbHelper.database.then((db) => db.query('patterns'));
    if (patterns.isEmpty) {
      debugPrint("No patterns found in DB.");
      return 0;
    }

    // 1.5 Fetch all Category Rules
    final allRules = await dbHelper.getAllCategoryRules();
    debugPrint("Loaded ${allRules.length} category rules.");

    // 2. Calculate the Look-back Date
    int sinceTimestamp;

    // Check for existing sync data (Incremental Sync)
    final int? lastSyncTime = prefs.getInt('lastSmsSyncTime');
    // Check for user-defined start date (First Run)
    final int? smsStartDate = prefs.getInt('smsStartDate');

    if (!forceFullScan && lastSyncTime != null) {
      // If we have synced before, only look for messages since then
      sinceTimestamp = lastSyncTime;
      debugPrint(
        "Syncing since last run: ${DateTime.fromMillisecondsSinceEpoch(sinceTimestamp)}",
      );
    } else if (smsStartDate != null) {
      // First time running sync OR forced full scan, use the user's selected start date
      sinceTimestamp = smsStartDate;
      debugPrint(
        "Full/Initial sync, using selected start date: ${DateTime.fromMillisecondsSinceEpoch(sinceTimestamp)}",
      );
    } else {
      // Fallback (shouldn't happen if setup flow is followed)
      sinceTimestamp =
          DateTime.now()
              .subtract(Duration(days: lookBackDays))
              .millisecondsSinceEpoch;
      debugPrint(
        "Fallback sync (60 days): ${DateTime.fromMillisecondsSinceEpoch(sinceTimestamp)}",
      );
    }

    // 3. Fetch Inbox (Filtered by Date for performance)
    // ONLY fetch messages newer than our sync timestamp
    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(
        SmsColumn.DATE,
      ).greaterThanOrEqualTo(sinceTimestamp.toString()),
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
            // 1. Get raw string. Group 1 is our number (e.g., "409.00" or ".409.00")
            String rawString = match.group(1) ?? "0";

            // 2. Remove commas (e.g. "1,200" -> "1200")
            String cleanString = rawString.replaceAll(',', '');

            // 3. Smart Extraction (UPDATED)
            // This regex finds the first valid number, even if it starts with a dot
            // Matches: "409", "409.00", ".409"
            RegExp numberRegex = RegExp(r'(\d*\.?\d+)');
            Match? numMatch = numberRegex.firstMatch(cleanString);

            double amount = 0.0;
            if (numMatch != null) {
              amount = double.tryParse(numMatch.group(0) ?? "0") ?? 0.0;
            }

            // Check duplicate and insert...
            final isDuplicate = await _checkForDuplicate(
              msg.address ?? "",
              amount,
              msgDate,
            );

            if (!isDuplicate) {
              // Auto-Categorization Logic
              int categoryId = 1; // Default: Uncategorized
              final lowerBody = body.toLowerCase();
              final lowerSender = (msg.address ?? "").toLowerCase();

              for (var rule in allRules) {
                final keyword = (rule['keyword'] as String).toLowerCase();
                // Check body OR sender for keyword
                // Simple logic: if message contains the keyword string anywhere
                if (lowerBody.contains(keyword) ||
                    lowerSender.contains(keyword)) {
                  categoryId = rule['categoryId'] as int;
                  debugPrint(
                    "Auto-categorized as $categoryId (Match: $keyword)",
                  );
                  break;
                }
              }

              debugPrint("Found NEW Transaction: $amount from ${msg.address}");
              await dbHelper.insertTransaction({
                'amount': amount,
                'sender': msg.address,
                'body': body,
                'date': msgDate,
                'type': pattern['messageType'],
                'categoryId': categoryId,
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

  Future<List<SmsMessage>> getInboxSms({int count = 20}) async {
    List<SmsMessage> messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    return messages.take(count).toList();
  }
}
