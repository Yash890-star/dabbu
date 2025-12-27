import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/message_helper.dart';
import '../utils/cms.dart';
import 'main_screen.dart';

class SmsParsingScreen extends StatefulWidget {
  final SmsMessage message;
  final int? existingPatternId; // For "Edit Pattern" mode
  final String? initialPatternName;
  final int? initialCategoryId;

  const SmsParsingScreen({
    super.key,
    required this.message,
    this.existingPatternId,
    this.initialPatternName,
    this.initialCategoryId,
  });

  @override
  State<SmsParsingScreen> createState() => _SmsParsingScreenState();
}

class _SmsParsingScreenState extends State<SmsParsingScreen> {
  // --- Token State ---
  List<String> _bodyTokens = [];
  List<String> _senderTokens = [];

  // --- Selection State ---
  // --- Selection State ---
  int? _selectedAmountIndex;
  // Prefix Range (Before Amount)
  int? _prefixStart;
  int? _prefixEnd;
  // Suffix Range (After Amount)
  int? _suffixStart;
  int? _suffixEnd;

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
    _patternNameController.text =
        widget.initialPatternName ?? widget.message.address ?? "Bank";
    if (widget.initialCategoryId != null) {
      _selectedCategoryId = widget.initialCategoryId!;
    }
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
      // Case 1: Select Amount
      if (_selectedAmountIndex == null) {
        _selectedAmountIndex = index;
        _prefixStart = null;
        _prefixEnd = null;
        _suffixStart = null;
        _suffixEnd = null;
      } else if (_selectedAmountIndex == index) {
        // Deselect Amount
        _selectedAmountIndex = null;
        _prefixStart = null;
        _prefixEnd = null;
        _suffixStart = null;
        _suffixEnd = null;
        _generatedRegex = "";
        return;
      }
      // Case 2: Prefix Selection (Before Amount)
      else if (index < _selectedAmountIndex!) {
        if (_prefixStart == null) {
          _prefixStart = index;
          _prefixEnd = index;
        } else {
          // If we already have a range, or tap is before start, reset
          if (_prefixEnd != _prefixStart || index < _prefixStart!) {
            _prefixStart = index;
            _prefixEnd = index;
          } else {
            // Extend to the right
            _prefixEnd = index;
          }
        }
      }
      // Case 3: Suffix Selection (After Amount)
      else {
        if (_suffixStart == null) {
          _suffixStart = index;
          _suffixEnd = index;
        } else {
          // Logic: Extend towards the right, or reset if clicking back?
          // For suffix, usually we read left-to-right (Amount ... Merchant).
          // If tap is before previous start (closer to amount), maybe reset?
          // Let's use simple logic: If tap > current end, extend. Else reset.
          if (index > _suffixEnd!) {
            _suffixEnd = index;
          } else {
            // Reset/Start New
            _suffixStart = index;
            _suffixEnd = index;
          }
        }
      }

      _generateRegex();
    });
  }

  void _generateRegex() {
    if (_selectedAmountIndex == null) {
      _generatedRegex = "";
      return;
    }

    String regex = "";

    // 1. PREFIX PART
    if (_prefixStart != null && _prefixEnd != null) {
      // A. The User-Selected Fixed Block
      List<String> fixedParts = [];
      for (int i = _prefixStart!; i <= _prefixEnd!; i++) {
        fixedParts.add(RegExp.escape(_bodyTokens[i]));
      }
      regex += fixedParts.join(r'\s+');

      // B. The Gap (if any)
      // Check distance to Amount
      // Last selected index is _prefixEnd.
      // Amount is _selectedAmountIndex.
      // E.g. Sel=1. Amt=3. Gap is index 2.
      if (_prefixEnd! < _selectedAmountIndex! - 1) {
        // There is a gap
        regex += r'\s+(?:.*?)\s+';

        // C. The Bridge (Last token before amount)
        // We ALWAYS include the token immediately preceding the amount as a strict anchor
        // UNLESS the user selected it as part of their fixed block.
        // Here, a gap exists, so user didn't select it.
        regex += RegExp.escape(_bodyTokens[_selectedAmountIndex! - 1]);
        regex += r'\s+';
      } else {
        // No gap (User selected up to the amount)
        regex += r'\s+';
      }
    }

    // 2. AMOUNT PART
    regex += r"(?:[^0-9\n]*)([0-9.,]+)";

    // 3. SUFFIX PART
    if (_suffixStart != null && _suffixEnd != null) {
      regex += r"\s+";

      // Gap handling for Suffix?
      // Amount is at AmtIndex.
      // Suffix starts at _suffixStart.
      // If _suffixStart > AmtIndex + 1, implicit gap?
      if (_suffixStart! > _selectedAmountIndex! + 1) {
        regex += r'(?:.*?)\s+';
      }

      List<String> suffixParts = [];
      for (int i = _suffixStart!; i <= _suffixEnd!; i++) {
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
            title: Text(CMS.sms_parsing['new_category_title']!),
            content: TextField(
              controller: catController,
              decoration: InputDecoration(
                hintText: CMS.sms_parsing['category_hint']!,
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
        SnackBar(content: Text(CMS.sms_parsing['error_incomplete']!)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.existingPatternId != null) {
        // --- EDIT MODE ---
        // 1. Delete associated transactions
        await DatabaseHelper.instance.deleteTransactionsByPatternId(
          widget.existingPatternId!,
        );

        // 2. Update Pattern
        await DatabaseHelper.instance.updatePattern({
          'id': widget.existingPatternId,
          'senderId': _selectedSenderToken,
          'name': _patternNameController.text.trim(),
          'patternRegex': _generatedRegex,
          'messageType': _transactionType,
          'extractionIndex': 1,
        });

        // 3. Force Rescan
        // This will re-import the current message AND history
        await MessageHelper().processNewMessages(forceFullScan: true);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(CMS.sms_parsing['success_message']!)),
        );
        Navigator.pop(context); // Go back to Settings
      } else {
        // --- CREATE MODE ---
        final patternId = await DatabaseHelper.instance.insertPattern({
          'senderId': _selectedSenderToken,
          'name': _patternNameController.text.trim(),
          'patternRegex': _generatedRegex,
          'messageType': _transactionType,
          'extractionIndex': 1,
        });

        // Insert the current one manually for immediate feedback (optional, but good for UX)
        // We replicate the parsing logic to get the amount accurately
        final regExp = RegExp(_generatedRegex, caseSensitive: false);
        final match = regExp.firstMatch(widget.message.body ?? "");
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
          'sender': widget.message.address ?? "Unknown",
          'body': widget.message.body,
          'date': widget.message.date ?? DateTime.now().millisecondsSinceEpoch,
          'type': _transactionType,
          'categoryId': _selectedCategoryId,
          'patternId': patternId,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('initialSetupDone', true);

        // Force Rescan to find older messages
        await MessageHelper().processNewMessages(forceFullScan: true);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error saving: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(CMS.sms_parsing['title']!)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Sender ID
              Text(
                CMS.sms_parsing['step_1_title']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
              Text(
                CMS.sms_parsing['step_2_title']!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                CMS.sms_parsing['step_2_subtitle']!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                    }
                    // Prefix Range Checking
                    else if (_prefixStart != null &&
                        _prefixEnd != null &&
                        index >= _prefixStart! &&
                        index <= _prefixEnd!) {
                      bgColor = Colors.blue;
                      textColor = Colors.white;
                      fontWeight = FontWeight.bold;
                    }
                    // Suffix Range Checking
                    else if (_suffixStart != null &&
                        _suffixEnd != null &&
                        index >= _suffixStart! &&
                        index <= _suffixEnd!) {
                      bgColor = Colors.blue;
                      textColor = Colors.white;
                      fontWeight = FontWeight.bold;
                    }
                    // Gap Highlighting (Prefix)
                    else if (_prefixEnd != null &&
                        _selectedAmountIndex != null &&
                        index > _prefixEnd! &&
                        index < _selectedAmountIndex!) {
                      bgColor = Colors.blue.shade50;
                    }
                    // Gap Highlighting (Suffix)
                    else if (_suffixStart != null &&
                        _selectedAmountIndex != null &&
                        index > _selectedAmountIndex! &&
                        index < _suffixStart!) {
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
                    "${CMS.sms_parsing['regex_preview']!}$_generatedRegex",
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 3. Details
              if (_selectedAmountIndex != null) ...[
                Text(
                  CMS.sms_parsing['step_3_title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    ChoiceChip(
                      label: Text(CMS.sms_parsing['debit_label']!),
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
                      label: Text(CMS.sms_parsing['credit_label']!),
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
                  decoration: InputDecoration(
                    labelText: CMS.sms_parsing['pattern_name_label']!,
                    helperText: CMS.sms_parsing['pattern_name_helper']!,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: CMS.sms_parsing['default_category_label']!,
                          border: const OutlineInputBorder(),
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
                          : Text(
                            CMS.sms_parsing['save_pattern_btn']!,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
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
