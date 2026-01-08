import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../utils/cms.dart';
import '../services/notification_service.dart';

class AddTransactionViewModel extends ChangeNotifier {
  // State
  bool isLoading = false;
  List<Map<String, dynamic>> categories = [];
  int selectedCategoryId = 1;

  // Form State managed in ViewModel for logic, but Controllers in UI for Text binding
  String type = 'debit';
  bool isGoalAddition = true;
  DateTime selectedDate = DateTime.now();

  // Context checks
  bool isGoalMode = false;
  int? activeGoalId;

  // Edit Mode Data
  Map<String, dynamic>? editingTransaction;

  void init({int? initialGoalId, Map<String, dynamic>? transaction}) {
    editingTransaction = transaction;

    // Determine Goal Mode
    if (initialGoalId != null) {
      isGoalMode = true;
      activeGoalId = initialGoalId;
    } else if (transaction != null && transaction['goalId'] != null) {
      isGoalMode = true;
      activeGoalId = transaction['goalId'];
    }

    // Initialize Values
    if (transaction != null) {
      // Edit Mode
      selectedDate = DateTime.fromMillisecondsSinceEpoch(transaction['date']);
      type = transaction['type'];
      selectedCategoryId = transaction['categoryId'] ?? 1;

      final existingFlag = transaction['is_goal_addition'];
      isGoalAddition = (existingFlag == null || existingFlag == 1);
    } else {
      // Create Mode
      if (isGoalMode) {
        isGoalAddition = true;
        type = 'debit';
      }
    }

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    categories = cats;

    // Validate selected ID
    if (categories.isNotEmpty &&
        !categories.any((c) => c['id'] == selectedCategoryId)) {
      selectedCategoryId = categories.first['id'];
    }
    notifyListeners();
  }

  void setType(String newType) {
    if (type != newType) {
      type = newType;
      notifyListeners();
    }
  }

  void setIsGoalAddition(bool value) {
    if (isGoalAddition != value) {
      isGoalAddition = value;
      notifyListeners();
    }
  }

  void setSelectedDate(DateTime date) {
    selectedDate = DateTime(
      date.year,
      date.month,
      date.day,
      DateTime.now().hour,
      DateTime.now().minute,
    );
    notifyListeners();
  }

  void setSelectedCategoryId(int id) {
    selectedCategoryId = id;
    notifyListeners();
  }

  // Returns error message or null if success
  Future<String?> saveTransaction({
    required String amountText,
    required String noteText,
  }) async {
    if (amountText.isEmpty) {
      return CMS.transaction['amount_error_empty'];
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return CMS.transaction['amount_error_invalid'];
    }

    isLoading = true;
    notifyListeners();

    try {
      final txData = {
        'amount': amount,
        'sender':
            noteText.isEmpty
                ? (isGoalMode
                    ? CMS.transaction['default_goal_contribution']!
                    : CMS.transaction['default_manual_entry']!)
                : noteText,
        'body': CMS.transaction['default_manual_body'],
        'date': selectedDate.millisecondsSinceEpoch,
        'type': type,
        'categoryId': selectedCategoryId,
        'patternId': null,
        'goalId': activeGoalId,
        'is_goal_addition': isGoalAddition ? 1 : 0,
      };

      if (editingTransaction != null) {
        // Update
        txData['id'] = editingTransaction!['id'];
        await DatabaseHelper.instance.updateTransaction(txData);
      } else {
        // Insert
        await DatabaseHelper.instance.insertTransaction(txData);
      }

      // Check Budget Alerts if it's an expense
      if (type == 'debit') {
        // We only check category of current transaction + global
        await NotificationService().checkBudgetThresholds(
          specificCategoryId: selectedCategoryId,
        );
        // Also Trigger global check (pass null or handle inside service to always check global)
        // Our service implementation checks global + specific category if provided.
        // But what if global budget is exceeded? The 'specificCategoryId' arg in our service
        // restricts the loop over categories, but Global Budget check is separate (Step 1).
        // So passing specificCategoryId is efficient and correct.
      }

      isLoading = false;
      notifyListeners();
      return null; // Success
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return "${CMS.transaction['error_saving']!}$e";
    }
  }
}
