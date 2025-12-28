import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/message_helper.dart';

enum SelectionMode { amount, anchor }

class SmsParsingViewModel extends ChangeNotifier {
  // --- State ---
  List<String> bodyTokens = [];
  List<String> senderTokens = [];

  int? selectedAmountIndex;
  int? prefixStart;
  int? prefixEnd;
  int? suffixStart;
  int? suffixEnd;

  String? selectedSenderToken;
  String generatedRegex = "";
  String transactionType = "debit";
  bool isLoading = false;

  List<Map<String, dynamic>> categories = [];
  int selectedCategoryId = 1;

  SelectionMode selectionMode = SelectionMode.amount;

  // --- Dependencies/Inputs ---
  final SmsMessage message;
  final int? existingPatternId;

  SmsParsingViewModel({
    required this.message,
    this.existingPatternId,
    int? initialCategoryId,
    String? initialPatternName,
  }) {
    if (initialCategoryId != null) {
      selectedCategoryId = initialCategoryId;
    }
  }

  // --- Initialization ---
  Future<void> init() async {
    _tokenizeMessage();
    _tokenizeSender();
    await _loadCategories();
  }

  void _tokenizeMessage() {
    final body = message.body ?? "";
    bodyTokens = body.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    notifyListeners();
  }

  void _tokenizeSender() {
    final address = message.address ?? "";
    senderTokens =
        address.split(RegExp(r'[-_\s]+')).where((e) => e.isNotEmpty).toList();
    if (senderTokens.isNotEmpty) {
      senderTokens.sort((a, b) => b.length.compareTo(a.length));
      selectedSenderToken = senderTokens.first;
    }
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    categories = cats;
    if (categories.isNotEmpty) {
      bool exists = categories.any((c) => c['id'] == selectedCategoryId);
      if (!exists) selectedCategoryId = categories.first['id'];
    }
    notifyListeners();
  }

  Future<void> refreshCategories() async {
    await _loadCategories();
  }

  // --- Selection Logic ---
  void handleTokenTap(int index) {
    if (selectionMode == SelectionMode.amount) {
      if (selectedAmountIndex == index) {
        // Deselect
        selectedAmountIndex = null;
        // Reset anchors as they depend on amount position relative to them
        prefixStart = null;
        prefixEnd = null;
        suffixStart = null;
        suffixEnd = null;
      } else {
        selectedAmountIndex = index;
        // Auto-switch to anchor mode for convenience? No, let's keep it explicit as per 'ChipSelector' requirement.
        // Actually, clearing anchors is safer when amount moves.
        prefixStart = null;
        prefixEnd = null;
        suffixStart = null;
        suffixEnd = null;
      }
    } else {
      // ANCHOR MODE
      if (selectedAmountIndex == null) return; // Need amount first

      if (index < selectedAmountIndex!) {
        // Prefix Logic
        if (prefixStart == null) {
          prefixStart = index;
          prefixEnd = index;
        } else {
          // If tapping existing range, maybe clear it?
          // Or just standard extend logic.
          if (index < prefixStart!)
            prefixStart = index;
          else if (index > prefixEnd!)
            prefixEnd = index;
          else {
            // Tapped inside. Maybe reset to just this token?
            prefixStart = index;
            prefixEnd = index;
          }
        }
      } else if (index > selectedAmountIndex!) {
        // Suffix Logic
        if (suffixStart == null) {
          suffixStart = index;
          suffixEnd = index;
        } else {
          if (index < suffixStart!)
            suffixStart = index;
          else if (index > suffixEnd!)
            suffixEnd = index;
          else {
            suffixStart = index;
            suffixEnd = index;
          }
        }
      }
    }

    // --- AUTO-CATEGORIZATION LOGIC ---
    // Check if the selected token (current index) matches known keywords
    if (selectionMode == SelectionMode.anchor) {
      final token = bodyTokens[index].toLowerCase().replaceAll(
        RegExp(r'[^a-z]'),
        '',
      );

      const debitKeywords = [
        'debit',
        'debited',
        'spent',
        'paid',
        'withdrawn',
        'sent',
        'transferred',
      ];
      const creditKeywords = [
        'credit',
        'credited',
        'received',
        'added',
        'deposited',
        'refund',
        'refunded',
      ];

      if (debitKeywords.contains(token)) {
        setTransactionType('debit');
      } else if (creditKeywords.contains(token)) {
        setTransactionType('credit');
      }
    }

    _generateRegex();
    notifyListeners();
  }

  void _generateRegex() {
    if (selectedAmountIndex == null) {
      generatedRegex = "";
      return;
    }

    String regex = "";

    // 1. PREFIX PART
    if (prefixStart != null && prefixEnd != null) {
      List<String> fixedParts = [];
      for (int i = prefixStart!; i <= prefixEnd!; i++) {
        fixedParts.add(RegExp.escape(bodyTokens[i]));
      }
      regex += fixedParts.join(r'\s+');

      if (prefixEnd! < selectedAmountIndex! - 1) {
        regex += r'\s+(?:.*?)\s+';
        regex += RegExp.escape(bodyTokens[selectedAmountIndex! - 1]);
        regex += r'\s+';
      } else {
        regex += r'\s+';
      }
    }

    // 2. AMOUNT PART
    regex += r"(?:[^0-9\n]*)([0-9.,]+)";

    // 3. SUFFIX PART
    if (suffixStart != null && suffixEnd != null) {
      regex += r"\s+";
      if (suffixStart! > selectedAmountIndex! + 1) {
        regex += r'(?:.*?)\s+';
      }

      List<String> suffixParts = [];
      for (int i = suffixStart!; i <= suffixEnd!; i++) {
        suffixParts.add(RegExp.escape(bodyTokens[i]));
      }
      regex += suffixParts.join(r'\s+');
    }

    generatedRegex = regex;
  }

  // --- Setters ---
  void setSelectedSenderToken(String token) {
    selectedSenderToken = token;
    notifyListeners();
  }

  void setTransactionType(String type) {
    transactionType = type;
    notifyListeners();
  }

  void setSelectedCategoryId(int id) {
    selectedCategoryId = id;
    notifyListeners();
  }

  void setSelectionMode(SelectionMode mode) {
    selectionMode = mode;
    notifyListeners();
  }

  // --- Actions ---
  Future<void> addNewCategory(String name) async {
    if (name.isNotEmpty) {
      await DatabaseHelper.instance.addCategory(name);
      await refreshCategories();
    }
  }

  /// Returns true if successful, false otherwise.
  /// Throws exception with error message if validation fails.
  Future<bool> savePattern(String patternName) async {
    if (generatedRegex.isEmpty || selectedSenderToken == null) {
      throw Exception(
        'Please select Bank Name, Amount, and at least one Anchor text.',
      );
    }

    isLoading = true;
    notifyListeners();

    try {
      if (existingPatternId != null) {
        // --- EDIT MODE ---
        await DatabaseHelper.instance.deleteTransactionsByPatternId(
          existingPatternId!,
        );

        await DatabaseHelper.instance.updatePattern({
          'id': existingPatternId,
          'senderId': selectedSenderToken,
          'name': patternName.trim(),
          'patternRegex': generatedRegex,
          'messageType': transactionType,
          'extractionIndex': 1,
        });

        await MessageHelper().processNewMessages(forceFullScan: true);

        isLoading = false;
        notifyListeners();
        return true; // Success (Pop)
      } else {
        // --- CREATE MODE ---
        final patternId = await DatabaseHelper.instance.insertPattern({
          'senderId': selectedSenderToken,
          'name': patternName.trim(),
          'patternRegex': generatedRegex,
          'messageType': transactionType,
          'extractionIndex': 1,
        });

        // Insert manual transaction for immediate feedback
        final regExp = RegExp(generatedRegex, caseSensitive: false);
        final match = regExp.firstMatch(message.body ?? "");
        double amount = 0.0;
        if (match != null) {
          String rawString = match.group(1) ?? "0";
          String cleanString = rawString.replaceAll(',', '');
          RegExp numberRegex = RegExp(r'(\d*\.?\d+)');
          Match? numMatch = numberRegex.firstMatch(cleanString);
          if (numMatch != null) {
            amount = double.tryParse(numMatch.group(0) ?? "0") ?? 0.0;
          }
        }

        await DatabaseHelper.instance.insertTransaction({
          'amount': amount,
          'sender': message.address ?? "Unknown",
          'body': message.body,
          'date': message.date ?? DateTime.now().millisecondsSinceEpoch,
          'type': transactionType,
          'categoryId': selectedCategoryId,
          'patternId': patternId,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('initialSetupDone', true);

        await MessageHelper().processNewMessages(forceFullScan: true);

        isLoading = false;
        notifyListeners();
        return true; // Success (Navigate Home)
      }
    } catch (e) {
      debugPrint("Error saving pattern: $e");
      isLoading = false;
      notifyListeners();
      return false; // Error handled internally
    }
  }
}
