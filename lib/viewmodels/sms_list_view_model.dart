import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';

class SmsListViewModel extends ChangeNotifier {
  List<SmsMessage> _allMessages = [];
  List<SmsMessage> filteredMessages = [];

  void init(List<SmsMessage> messages) {
    _allMessages = messages;
    filteredMessages = messages;
    notifyListeners();
  }

  void filterMessages(String query) {
    if (query.isEmpty) {
      filteredMessages = _allMessages;
    } else {
      final lowerQuery = query.toLowerCase();
      filteredMessages =
          _allMessages.where((msg) {
            final address = (msg.address ?? "").toLowerCase();
            final body = (msg.body ?? "").toLowerCase();
            return address.contains(lowerQuery) || body.contains(lowerQuery);
          }).toList();
    }
    notifyListeners();
  }
}
