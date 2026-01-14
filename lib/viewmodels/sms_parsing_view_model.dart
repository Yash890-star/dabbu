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
  Set<int> selectedAnchorIndices = {};

  String? selectedSenderToken;
  String generatedRegex = "";
  String transactionType = "debit";
  bool isLoading = false;
  bool isLiquid = true;

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
        selectedAmountIndex = null;
      } else {
        selectedAmountIndex = index;
        // Remove this index from anchors if it was selected
        selectedAnchorIndices.remove(index);
      }
    } else {
      // ANCHOR MODE
      if (selectedAmountIndex == null) return; // Need amount first

      if (index == selectedAmountIndex) {
        return; // Cannot be anchor if it is amount
      }

      if (selectedAnchorIndices.contains(index)) {
        selectedAnchorIndices.remove(index);
      } else {
        selectedAnchorIndices.add(index);
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

    // sort all indices (anchors + amount)
    final allIndices = [...selectedAnchorIndices, selectedAmountIndex!]..sort();

    String regex = "";

    for (int i = 0; i < allIndices.length; i++) {
      int currentIndex = allIndices[i];
      bool isAmount = (currentIndex == selectedAmountIndex);

      if (i > 0) {
        int prevIndex = allIndices[i - 1];
        int gap = currentIndex - prevIndex - 1;

        if (gap > 0) {
          // Gap exists -> Wildcard
          regex += r'\s+(?:.*?)\s+';
        } else {
          // Adjacent -> Space
          regex += r'\s+';
        }
      }

      if (isAmount) {
        // Capture Amount (handle dirty tokens like 'INR6000')
        regex += r"(?:[^0-9\n]*)([0-9.,]+)";
      } else {
        // Literal anchor
        regex += RegExp.escape(bodyTokens[currentIndex]);
      }
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

  void setIsLiquid(bool value) {
    isLiquid = value;
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
        // (Existing logic: delete txns, update pattern, rescan)
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
          'isLiquid': isLiquid ? 1 : 0,
        });

        await MessageHelper().processNewMessages(forceFullScan: true);

        isLoading = false;
        notifyListeners();
        return true; // Success (Pop)
      } else {
        // --- CREATE MODE ---

        // Check for duplicates
        final exists = await DatabaseHelper.instance.checkPatternExists(
          selectedSenderToken!,
          generatedRegex,
        );

        if (exists) {
          throw Exception(
            'This pattern already exists for $selectedSenderToken.',
          );
        }

        final patternId = await DatabaseHelper.instance.insertPattern({
          'senderId': selectedSenderToken,
          'name': patternName.trim(),
          'patternRegex': generatedRegex,
          'messageType': transactionType,
          'extractionIndex': 1,
          'isLiquid': isLiquid ? 1 : 0,
        });

        // Insert manual transaction for immediate feedback
        // BUT FIRST: Check if this transaction already exists to key duplicate logic consistent
        final txDate = message.date ?? DateTime.now().millisecondsSinceEpoch;
        final txSender = message.address ?? "Unknown";

        final txExists = await DatabaseHelper.instance.checkTransactionExists(
          txSender,
          txDate,
        );

        if (!txExists) {
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
            'sender': txSender,
            'body': message.body,
            'date': txDate,
            'type': transactionType,
            'categoryId': selectedCategoryId,
            'patternId': patternId,
            'isLiquid': isLiquid ? 1 : 0,
          });
        }

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
