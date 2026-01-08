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
            textTheme: GoogleFonts.interTextTheme(), // Apply Inter Font
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
              systemOverlayStyle: SystemUiOverlayStyle.dark, // Dark icons
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
            textTheme: GoogleFonts.interTextTheme(
              ThemeData.dark().textTheme,
            ), // Apply Inter Font
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
              systemOverlayStyle: SystemUiOverlayStyle.light, // Light icons
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
