import 'package:dabbu/screens/initial_setup_screen.dart';
import 'package:dabbu/screens/main_screen.dart';
import 'package:dabbu/utils/app_colors.dart';
import 'package:dabbu/widgets/custom_error_widget.dart'; // Import CustomErrorWidget
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import Services for SystemChrome
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import 'package:dabbu/utils/theme_controller.dart';
import 'package:dabbu/services/notification_service.dart'; // Import NotificationService
import 'package:dabbu/services/background_service.dart'; // Import BackgroundService

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set default System UI Overlay Style (Status Bar Color)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      statusBarIconBrightness:
          Brightness.dark, // Dark icons for light mode default
    ),
  );

  // Initialize Theme
  final themeController = ThemeController();
  await themeController.loadTheme();

  // Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.init();

  // Initialize Background Service
  final backgroundService = BackgroundService();
  await backgroundService.init();
  // Optional: Register immediately for dev, or let settings control it.
  // For Phase 2 verification, we will rely on settings or manual trigger.

  final prefs = await SharedPreferences.getInstance();
  bool showOptions = prefs.getBool('initialSetupDone') ?? false;

  // Set Custom Error Widget
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(errorDetails: details);
  };

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
            textTheme: GoogleFonts.interTextTheme().apply(
              bodyColor: AppColors.textPrimaryLight,
              displayColor: AppColors.textPrimaryLight,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryLight,
              brightness: Brightness.light,
              primary: AppColors.primaryLight,
              onPrimary: Colors.white,
              secondary: AppColors.secondary,
              surface: AppColors.surfaceLight,
              onSurface: AppColors.textPrimaryLight,
            ),
            scaffoldBackgroundColor: AppColors.backgroundLight,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.backgroundLight,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.textPrimaryLight,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
            ),
            cardTheme: CardThemeData(
              color: AppColors.surfaceLight,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), // V4: Rounder
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: AppColors.surfaceLight,
              indicatorColor: AppColors.primaryLight.withValues(alpha: 0.2),
              iconTheme: WidgetStateProperty.all(
                const IconThemeData(color: AppColors.textSecondaryLight),
              ),
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.dark().textTheme,
            ).apply(
              bodyColor: AppColors.textPrimary,
              displayColor: AppColors.textPrimary,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
              surface: AppColors.surfaceDark,
              onSurface: AppColors.textPrimary,
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
              secondary: AppColors.secondary,
            ),
            scaffoldBackgroundColor: AppColors.backgroundDark,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.backgroundDark,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
            cardTheme: CardThemeData(
              color: AppColors.surfaceDark,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20), // V4: Rounder
                side: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.5),
                ),
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
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  );
                }
                return const TextStyle(color: AppColors.textSecondary);
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const IconThemeData(color: AppColors.primary);
                }
                return const IconThemeData(color: AppColors.textSecondary);
              }),
            ),
          ),
          home: showOptions ? InitialSetupScreen() : MainScreen(),
        );
      },
    );
  }
}
