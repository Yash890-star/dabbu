import 'package:another_telephony/telephony.dart';
import 'database_helper.dart';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
backgroundMessageHandler(SmsMessage message) async {
  MessageHelper.handleNewMessage(message);
}

class MessageHelper {
  static final transactionTable = 'transactions';
  static final messageAddress = 'AXISBK';

  static Future<void> initTelephony() async {
    final Telephony telephony = Telephony.instance;
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted == true) {
      log("SMS permissions granted.");
      // telephony.listenIncomingSms(
      //     onNewMessage: (SmsMessage message) async {
      //       handleNewMessage(message);
      //     },
      //     onBackgroundMessage: backgroundMessageHandler
      // );
    } else {
      log("SMS permissions not granted or user denied.");
    }
  }

  static void handleNewMessage(SmsMessage message) async {
    log(
      "New SMS: ${message.body} ${message.address} ${message.date} ${message.read}",
    );
    try {
      insertTransactionsIntoDb({
        "cost": "10",
        "date": "${message.date}",
        "type": "DEBITED",
        "entity": "${message.address}",
      });
    } catch (e) {
      log("Error: $e");
    }
  }

  static String getIsoDateStringFromEpoch(String? date) {
    if (date != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        int.parse(date),
      ).toIso8601String();
    } else {
      return DateTime.now().toIso8601String();
    }
  }

  static void insertTransactionsIntoDb(Map<String, String> data) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      data["date"] = getIsoDateStringFromEpoch(data['date']);
      int id = await db.insert(transactionTable, data);
      log("$id inserted -  data $data");
      List<Map> maps = await db.query(transactionTable);
      log("$maps");
    } catch (e) {
      log("Error: $e");
      throw Exception("Error inserting into db error $e");
    }
  }

  static String getCurrentMonthFirstDate() {
    final DateTime now = DateTime.now();
    final DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
    return firstDayOfMonth.millisecondsSinceEpoch.toString();
  }

  static Future<void> getNewTransactions() async {
    try {
      List<SmsMessage> messages;
      final SharedPreferencesAsync storage = SharedPreferencesAsync();
      String? latestTimeStamp = await storage.getString("latestTimeStamp");
      log("latestTimeStamp $latestTimeStamp");
      if (latestTimeStamp == null) {
        messages = await Telephony.instance.getInboxSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
          filter: SmsFilter.where(SmsColumn.ADDRESS)
              .like("%$messageAddress%")
              .and(SmsColumn.DATE)
              .greaterThan(getCurrentMonthFirstDate()),
          sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
        );
      } else {
        messages = await Telephony.instance.getInboxSms(
          columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
          filter: SmsFilter.where(SmsColumn.ADDRESS)
              .like("%$messageAddress%")
              .and(SmsColumn.DATE)
              .greaterThan(latestTimeStamp),
        );
      }
      log("messages - $messages");
      latestTimeStamp = DateTime.now().millisecondsSinceEpoch.toString();
      await storage.setString("latestTimeStamp", latestTimeStamp);
      for (var message in messages) {
        parseMessageAndInsert(message);
        log('''
          new messages - 
            ${message.body} 
            ${getIsoDateStringFromEpoch(message.date.toString())}
            ${message.address}
        ''');
      }
    } catch (e) {
      log("$e");
    }
  }

  static void parseMessageAndInsert(SmsMessage message) {
    if (message.address!.contains("AXISBK")) {
      if (message.body!.contains("debited")) {
        final RegExp regex = RegExp(
          r"INR\s(?<cost>[\d.]+)\s(debited)\s.+\s(?<date>[\d+\-\,\s:]+)(?<entity>.+)",
        );
        final RegExpMatch? match = regex.firstMatch(message.body!);
        final Map<String, String?> extractedData = {};
        if (match != null) {
          for (final String groupName in match.groupNames) {
            extractedData[groupName] = match.namedGroup(groupName);
          }
        }
        log("extraced data $extractedData");
        if (extractedData["cost"] != null &&
            extractedData["date"] != null &&
            extractedData["entity"] != null) {
          final monthOfTransaction =
              DateTime.fromMillisecondsSinceEpoch(message.date!).month;
          final yearOfTransaction =
              DateTime.fromMillisecondsSinceEpoch(message.date!).year;
          insertTransactionsIntoDb({
            "cost": extractedData["cost"]!,
            "date": message.date.toString(),
            "type": "DEBITED",
            "entity": extractedData["entity"]!,
            "month": monthOfTransaction.toString(),
            "year": yearOfTransaction.toString(),
          });
        }
      }
    }
  }

  static Future<List<SmsMessage>> getFewMessagesFromCurrentBank(String value) async {
    List<SmsMessage> messages = await Telephony.instance.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      filter: SmsFilter.where(SmsColumn.ADDRESS)
          .like("%$value%"),
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );
    if (messages.length > 10) {
      return messages.sublist(0, 10);
    }
    return messages;
  }

}
