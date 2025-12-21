import 'package:dabbu/screens/initial_setup_screen.dart';
import 'package:dabbu/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  bool showOptions = prefs.getBool('initialSetupDone') ?? false;
  runApp(MyApp(showOptions: !showOptions));
}

class MyApp extends StatelessWidget {
  final bool showOptions;
  const MyApp({super.key, required this.showOptions});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dabbu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: showOptions ? InitialSetupScreen() : MainScreen(),
    );
  }
}
