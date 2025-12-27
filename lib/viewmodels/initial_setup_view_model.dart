import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InitialSetupViewModel extends ChangeNotifier {
  bool isLoading = false;

  Future<void> saveName(String name) async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);

    isLoading = false;
    notifyListeners();
  }
}
