import 'package:dabbu/screens/initial_setup_screen.dart';
import 'package:dabbu/screens/main_screen.dart';
import 'package:dabbu/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dabbu/utils/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Theme
  final themeController = ThemeController();
  await themeController.loadTheme();

  final prefs = await SharedPreferences.getInstance();
  bool showOptions = prefs.getBool('initialSetupDone') ?? false;
  runApp(MyApp(showOptions: !showOptions));
}

class MyApp extends StatelessWidget {
  final bool showOptions;
  const MyApp({super.key, required this.showOptions});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController(),
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Dabbu',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode, // Dynamic Theme Mode
          theme: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.light,
              primary: AppColors.primary,
              secondary: AppColors.secondary,
            ),
            scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS Off-White
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF2F2F7),
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
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
              surface: const Color(0xFF1E293B), // Slate 800 for cards
              primary: AppColors.primary,
              secondary: AppColors.secondary,
              onSurface: Colors.white,
            ),
            scaffoldBackgroundColor: AppColors.surfaceDark, // Slate 900
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.surfaceDark,
              surfaceTintColor: Colors.transparent, // Avoid tint on scroll
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E293B), // Slate 800
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: AppColors.surfaceDark,
              indicatorColor: AppColors.primary.withValues(alpha: 0.2),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
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
      },
    );
  }
}
