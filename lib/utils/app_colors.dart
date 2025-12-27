import 'package:flutter/material.dart';

class AppColors {
  // Semantic Colors
  static const Color income = Color(0xFF2ECC71); // Emerald Green
  static const Color success = Color(0xFF2ECC71); // Emerald Green
  static const Color expense = Color(0xFFE74C3C); // Alizarin Red
  static const Color delete = Color(0xFFE74C3C); // Alizarin Red
  static const Color primary = Color(0xFF00796B); // Teal 700
  static const Color secondary = Color(0xFF00BFA5); // Teal Accent 700
  static const Color surfaceDark = Color(0xFF0F172A); // Slate 900

  // Settings Icons
  static const Color walletIcon = Color(0xFF6C63FF); // Modern Blurple
  static const Color subscriptionIcon = Color(0xFFA569BD); // Wisteria Purple
  static const Color archiveIcon = Color(0xFFF39C12); // Orange
  static const Color defaultCategoryColor = Colors.grey;
  static const Color defaultGoalColor = Color(0xFF00BFA5); // Teal Accent
  static const Color onColoredBackground = Colors.white;

  // Backgrounds with Opacity (Helpers)
  static Color get incomeBackground => income.withValues(alpha: 0.1);
  static Color get expenseBackground => expense.withValues(alpha: 0.1);

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
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.indigo,
    Colors.cyan,
  ];
}
