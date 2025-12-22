import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import 'main_screen.dart';

class SmsParsingScreen extends StatefulWidget {
  final SmsMessage message;

  const SmsParsingScreen({super.key, required this.message});

  @override
  State<SmsParsingScreen> createState() => _SmsParsingScreenState();
}

class _SmsParsingScreenState extends State<SmsParsingScreen> {
  // --- Token State ---
  List<String> _bodyTokens = [];
  List<String> _senderTokens = [];

  // --- Selection State ---
  int? _selectedAmountIndex;
  int? _selectedPrefixIndex; // The anchor BEFORE the amount
  int? _selectedSuffixIndex; // The anchor AFTER the amount
  String? _selectedSenderToken;

  // --- Metadata State ---
  String _generatedRegex = "";
  String _transactionType = "debit";
  bool _isLoading = false;
  final TextEditingController _patternNameController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  int _selectedCategoryId = 1;

  @override
  void initState() {
    super.initState();
    _tokenizeMessage();
    _tokenizeSender();
    _loadCategories();
    _patternNameController.text = widget.message.address ?? "Bank";
  }

  void _tokenizeMessage() {
    final body = widget.message.body ?? "";
    _bodyTokens =
        body.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  }

  void _tokenizeSender() {
    final address = widget.message.address ?? "";
    _senderTokens =
        address.split(RegExp(r'[-_\s]+')).where((e) => e.isNotEmpty).toList();
    if (_senderTokens.isNotEmpty) {
      _senderTokens.sort((a, b) => b.length.compareTo(a.length));
      _selectedSenderToken = _senderTokens.first;
    }
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    setState(() {
      _categories = cats;
      if (_categories.isNotEmpty) {
        bool exists = _categories.any((c) => c['id'] == _selectedCategoryId);
        if (!exists) _selectedCategoryId = _categories.first['id'];
      }
    });
  }

  // --- THE NEW SELECTION LOGIC ---
  void _handleTokenTap(int index) {
    setState(() {
      // Case 1: Select Amount (First tap or resetting)
      if (_selectedAmountIndex == null) {
        _selectedAmountIndex = index;
        _selectedPrefixIndex = null; // Reset anchors when amount changes
        _selectedSuffixIndex = null;
      }
      // Case 2: Deselect Amount (Tapping it again)
      else if (_selectedAmountIndex == index) {
        _selectedAmountIndex = null;
        _selectedPrefixIndex = null;
        _selectedSuffixIndex = null;
        _generatedRegex = "";
        return;
      }
      // Case 3: Select Anchor
      else {
        if (index < _selectedAmountIndex!) {
          // If tapping before amount -> Toggle Prefix
          _selectedPrefixIndex = (_selectedPrefixIndex == index) ? null : index;
        } else {
          // If tapping after amount -> Toggle Suffix
          _selectedSuffixIndex = (_selectedSuffixIndex == index) ? null : index;
        }
      }

      _generateRegex(); // Re-calculate regex immediately
    });
  }

  void _generateRegex() {
    if (_selectedAmountIndex == null) {
      _generatedRegex = "";
      return;
    }

    String regex = "";

    // 1. PREFIX PART
    if (_selectedPrefixIndex != null) {
      List<String> prefixParts = [];
      for (int i = _selectedPrefixIndex!; i < _selectedAmountIndex!; i++) {
        prefixParts.add(RegExp.escape(_bodyTokens[i]));
      }
      regex += "${prefixParts.join(r'\s+')}\\s+";
    }

    // 2. AMOUNT PART (UPDATED FIX)
    // We add (?:[^0-9\n]*) to ignore "Rs.", "INR", ":", etc. inside the token
    regex += r"(?:[^0-9\n]*)([0-9.,]+)";

    // 3. SUFFIX PART
    if (_selectedSuffixIndex != null) {
      regex += r"\s+";
      List<String> suffixParts = [];
      for (int i = _selectedAmountIndex! + 1; i <= _selectedSuffixIndex!; i++) {
        suffixParts.add(RegExp.escape(_bodyTokens[i]));
      }
      regex += suffixParts.join(r'\s+');
    }

    setState(() {
      _generatedRegex = regex;
    });
  }

  // ... _addNewCategory (Same as before) ...
  Future<void> _addNewCategory() async {
    TextEditingController catController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("New Category"),
            content: TextField(
              controller: catController,
              decoration: const InputDecoration(
                hintText: "Category Name (e.g. Groceries)",
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (catController.text.isNotEmpty) {
                    await DatabaseHelper.instance.addCategory(
                      catController.text,
                    );
                    await _loadCategories();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
                child: const Text("Add"),
              ),
            ],
          ),
    );
  }

  // ... _savePatternAndContinue (Same as before) ...
  Future<void> _savePatternAndContinue() async {
    if (_generatedRegex.isEmpty || _selectedSenderToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select Bank Name, Amount, and at least one Anchor text.",
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final patternId = await DatabaseHelper.instance.insertPattern({
        'senderId': _selectedSenderToken,
        'name': _patternNameController.text.trim(),
        'patternRegex': _generatedRegex,
        'messageType': _transactionType,
        'extractionIndex': 1,
      });

      // NEW & ROBUST logic (Matches MessageHelper)
      String rawToken = _bodyTokens[_selectedAmountIndex!];

      // 1. Remove commas (e.g. "1,200" -> "1200")
      String cleanToken = rawToken.replaceAll(',', '');

      // 2. Smart Extraction: Find the first valid number pattern
      // This handles "Rs.409.00", ".409.00", "409", etc.
      RegExp numberRegex = RegExp(r'(\d*\.?\d+)');
      Match? numMatch = numberRegex.firstMatch(cleanToken);

      double amount = 0.0;
      if (numMatch != null) {
        amount = double.tryParse(numMatch.group(0) ?? "0") ?? 0.0;
      }

      await DatabaseHelper.instance.insertTransaction({
        'amount': amount,
        'sender': widget.message.address ?? "Unknown",
        'body': widget.message.body,
        'date': widget.message.date ?? DateTime.now().millisecondsSinceEpoch,
        'type': _transactionType,
        'categoryId': _selectedCategoryId,
        'patternId': patternId,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('initialSetupDone', true);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("Error saving: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Train Parser")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Sender ID
              const Text(
                "1. Select Bank Name:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    _senderTokens.map((token) {
                      final isSelected = token == _selectedSenderToken;
                      return ChoiceChip(
                        label: Text(token),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedSenderToken = token);
                          }
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),

              // 2. Body Tokens (Visual Selection)
              const Text(
                "2. Select AMOUNT (Green) and ANCHOR TEXT (Blue):",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                "Tap amount first, then tap words before/after it to lock the pattern.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 8, // Added more spacing for better touch targets
                  children: List.generate(_bodyTokens.length, (index) {
                    // Determine Colors based on state
                    Color bgColor = Colors.transparent;
                    Color textColor = Colors.black87;
                    FontWeight fontWeight = FontWeight.normal;

                    if (index == _selectedAmountIndex) {
                      bgColor = Colors.green; // Amount is Green
                      textColor = Colors.white;
                      fontWeight = FontWeight.bold;
                    } else if (index == _selectedPrefixIndex ||
                        index == _selectedSuffixIndex) {
                      bgColor = Colors.blue; // Anchors are Blue
                      textColor = Colors.white;
                      fontWeight = FontWeight.bold;
                    } else if (_selectedPrefixIndex != null &&
                        _selectedAmountIndex != null &&
                        index > _selectedPrefixIndex! &&
                        index < _selectedAmountIndex!) {
                      // Highlight words BETWEEN anchor and amount lightly
                      bgColor = Colors.blue.shade50;
                    }

                    return InkWell(
                      onTap: () => _handleTokenTap(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              (bgColor == Colors.transparent)
                                  ? Border.all(color: Colors.grey.shade300)
                                  : null,
                        ),
                        child: Text(
                          _bodyTokens[index],
                          style: TextStyle(
                            color: textColor,
                            fontWeight: fontWeight,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 8),
              // Show Regex Preview for debugging/confirmation
              if (_generatedRegex.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey.shade200,
                  child: Text(
                    "Regex: $_generatedRegex",
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 3. Details
              if (_selectedAmountIndex != null) ...[
                const Text(
                  "3. Details",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    ChoiceChip(
                      label: const Text("Debit"),
                      selected: _transactionType == 'debit',
                      selectedColor: Colors.red.shade100,
                      labelStyle: TextStyle(
                        color:
                            _transactionType == 'debit'
                                ? Colors.red
                                : Colors.black,
                      ),
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() => _transactionType = 'debit');
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text("Credit"),
                      selected: _transactionType == 'credit',
                      selectedColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color:
                            _transactionType == 'credit'
                                ? Colors.green
                                : Colors.black,
                      ),
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() => _transactionType = 'credit');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _patternNameController,
                  decoration: const InputDecoration(
                    labelText: "Pattern Name",
                    helperText: "e.g., 'Axis Credit Card'",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Default Category",
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedCategoryId,
                            isDense: true,
                            items:
                                _categories.map((cat) {
                                  return DropdownMenuItem<int>(
                                    value: cat['id'],
                                    child: Text(cat['name']),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategoryId = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.blue,
                        size: 30,
                      ),
                      onPressed: _addNewCategory,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _savePatternAndContinue,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green.shade600,
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            "Save Pattern",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                ),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
