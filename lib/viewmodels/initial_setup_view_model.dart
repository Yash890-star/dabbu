import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InitialSetupViewModel extends ChangeNotifier {
  bool isLoading = false;

  Future<void> saveUserData(String name, {double? budget}) async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);

    if (budget != null && budget > 0) {
      await prefs.setDouble('monthly_budget', budget);
    }

    isLoading = false;
    notifyListeners();
  }
}
