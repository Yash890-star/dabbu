import 'package:flutter/material.dart';

class AppColors {
  // Semantic Colors
  static const Color income = Colors.green;
  static const Color expense = Colors.red;
  static const Color delete = Colors.red;

  // Settings Icons
  static const Color walletIcon = Colors.deepPurple;
  static const Color subscriptionIcon = Colors.purple;
  static const Color archiveIcon = Colors.orange;
  static const Color defaultCategoryColor = Colors.grey;
  static const Color defaultGoalColor = Colors.blue;
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
