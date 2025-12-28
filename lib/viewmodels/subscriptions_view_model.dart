import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/subscription_service.dart';

class SubscriptionsViewModel extends ChangeNotifier {
  List<Map<String, dynamic>> subscriptions = [];
  bool isLoading = true;

  Future<void> loadSubscriptions() async {
    isLoading = true;
    notifyListeners();

    final subs = await DatabaseHelper.instance.getAllSubscriptions();
    subscriptions = subs;
    isLoading = false;
    notifyListeners();
  }

  Future<void> deleteSubscription(int id) async {
    await DatabaseHelper.instance.deleteSubscription(id);
    await loadSubscriptions();
  }

  Future<List<Map<String, dynamic>>> scanForSubscriptions() async {
    isLoading = true;
    notifyListeners();

    try {
      final candidates = await SubscriptionService().scanForSubscriptions();
      return candidates;
    } finally {
      // Note: scanForSubscriptions doesn't change stored subscriptions,
      // but we need to reset isLoading.
      // And typically we want to show existing subs again if we just showed loading.
      // However, if we just await this method, the UI might handle the loading state locally
      // or we handle it here.
      // A better UX: 'isLoading' covers the list. If we scan, maybe we show an overlay?
      // For now, consistent with Screen logic: set loading, scan, return candidates, reload list.
      await loadSubscriptions();
    }
  }

  Future<void> createSubscription(Map<String, dynamic> data) async {
    await DatabaseHelper.instance.createSubscription(data);
    await loadSubscriptions();
  }
}
