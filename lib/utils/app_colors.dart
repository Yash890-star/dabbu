import 'package:flutter/material.dart';

class AppColors {
  // Design System V4 - Electric & Deep
  // Dark Mode (Primary)
  static const Color backgroundDark = Color(0xFF0D1619); // Deep Gunmetal/Black
  static const Color surfaceDark = Color(0xFF1A262B); // Lighter Gunmetal
  static const Color primary = Color(0xFF1CD0EC); // Electric Cyan
  static const Color onPrimary = Color(0xFF000000); // Black Text on Cyan
  static const Color secondary = Color(0xFF263238); // Blue Grey
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);

  // Light Mode (Derived)
  static const Color backgroundLight = Color(0xFFF0F4F5); // Cool White
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(
    0xFF0097A7,
  ); // Darker Cyan for Light Mode
  static const Color textPrimaryLight = Color(0xFF102027); // Deep Blue-Black
  static const Color textSecondaryLight = Color(0xFF546E7A);

  // Semantic Colors
  static const Color income = Color(0xFF4CAF50); // Success Green
  static const Color expense = Color(0xFFFF5252); // Error Red
  static const Color delete = Color(0xFFFF5252);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFFF5252);

  // Settings Icons
  static const Color walletIcon = Color(0xFF6C63FF); // Modern Blurple
  static const Color subscriptionIcon = Color(0xFFA569BD); // Wisteria Purple
  static const Color archiveIcon = Color(0xFFF39C12); // Orange
  static const Color defaultCategoryColor = Colors.grey;
  static const Color defaultGoalColor = Color(0xFF00BFA5); // Teal Accent
  static const Color onColoredBackground = Colors.white;

  // Backgrounds with Opacity
  static Color get incomeBackground => income.withValues(alpha: 0.1);
  static Color get expenseBackground => expense.withValues(alpha: 0.1);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1CD0EC), Color(0xFF0097A7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassGradient = LinearGradient(
    colors: [
      const Color(0xFF1CD0EC).withValues(alpha: 0.15),
      const Color(0xFF1CD0EC).withValues(alpha: 0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Goal/Category Selection Colors
  static const List<Color> selectionColors = [
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  // Category Selection Colors (Comprehensive)
  static const List<Color> categoryColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

  // Chart Colors (for Analytics)
  static const List<Color> chartColors = [
    Color(0xFF1CD0EC), // Primary Cyan
    Color(0xFF0097A7), // Dark Cyan
    Color(0xFF4CAF50), // Green
    Color(0xFFFF5252), // Red
    Color(0xFFFFA726), // Orange
    Color(0xFFAB47BC), // Purple
    Color(0xFF7E57C2), // Deep Purple
    Color(0xFF26C6DA), // Light Blue
    Color(0xFFFF7043), // Deep Orange
    Color(0xFF78909C), // Blue Grey
  ];
}
