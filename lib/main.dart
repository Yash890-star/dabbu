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
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Follow system setting
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Colors.deepPurpleAccent.withValues(alpha: 0.2),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          surface: const Color(
            0xFF1E1E1E,
          ), // Slightly lighter than black for cards
          primary: Colors.deepPurpleAccent,
          secondary: Colors.tealAccent,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          surfaceTintColor: Colors.transparent, // Avoid tint on scroll
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Colors.deepPurpleAccent.withValues(alpha: 0.2),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              );
            }
            return const TextStyle(color: Colors.white70);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            // Use white70 for unselected icons to ensure visibility on black
            return const IconThemeData(color: Colors.white70);
          }),
        ),
      ),
      home: showOptions ? InitialSetupScreen() : MainScreen(),
    );
  }
}
