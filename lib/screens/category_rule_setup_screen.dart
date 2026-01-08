import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../services/database_helper.dart';
import '../widgets/sms/sms_code_block.dart';
import 'sms_list_screen.dart';

class CategoryRuleSetupScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final String? initialBody;
  final String? initialSender;

  const CategoryRuleSetupScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.initialBody,
    this.initialSender,
  });

  @override
  State<CategoryRuleSetupScreen> createState() =>
      _CategoryRuleSetupScreenState();
}

class _CategoryRuleSetupScreenState extends State<CategoryRuleSetupScreen> {
  // We use simple String state instead of SmsMessage to avoid constructor issues
  // or dependency on a specific plugin class for non-inbox data.
  String? _sourceBody;
  String? _sourceAddress;

  List<SmsMessage> _inboxMessages = [];
  bool _isLoading = true;
  List<String> _bodyTokens = [];
  List<TextRange> _tokenRanges =
      []; // Track where tokens are in original string
  Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialBody != null) {
      // Pre-fill if passed from Transaction Details
      _onManualDataLoaded(widget.initialBody!, widget.initialSender);
      _isLoading = false;
    } else {
      _fetchInbox();
    }
  }

  void _onManualDataLoaded(String body, String? sender) {
    _populateTokens(body);
    setState(() {
      _sourceBody = body;
      _sourceAddress = sender;
    });
  }

  Future<void> _fetchInbox() async {
    final Telephony telephony = Telephony.instance;
    try {
      // 1. Check Permissions first (though usually granted by now)
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      if (permissionsGranted != true) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Load Inbox
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (mounted) {
        setState(() {
          _inboxMessages = messages;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading SMS: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSmsPicked(SmsMessage msg) {
    if (msg.body == null) return;
    _populateTokens(msg.body!);

    setState(() {
      _sourceBody = msg.body;
      _sourceAddress = msg.address;
      _selectedIndices = {};
    });
  }

  void _populateTokens(String body) {
    final List<String> tokens = [];
    final List<TextRange> ranges = [];

    // Split by common delimiters: space, /, -, comma, newline
    final regExp = RegExp(r"[^ \s/,\-]+");
    final matches = regExp.allMatches(body);

    for (var m in matches) {
      tokens.add(m.group(0)!);
      ranges.add(TextRange(start: m.start, end: m.end));
    }

    _bodyTokens = tokens;
    _tokenRanges = ranges;
  }

  void _toggleToken(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _saveRule() async {
    if (_selectedIndices.isEmpty || _sourceBody == null) return;

    final sortedIndices = _selectedIndices.toList()..sort();
    final firstIndex = sortedIndices.first;
    final lastIndex = sortedIndices.last;

    final startChar = _tokenRanges[firstIndex].start;
    final endChar = _tokenRanges[lastIndex].end;

    final keyword = _sourceBody!.substring(startChar, endChar);

    // 1. Validation: Check if rule exists
    final existingRule = await DatabaseHelper.instance.getRuleByKeyword(
      keyword,
    );

    if (existingRule != null) {
      if (!mounted) return;

      // Rule exists. Check if it's for the same category or different one.
      final existingCatId = existingRule['categoryId'] as int;

      if (existingCatId == widget.categoryId) {
        // Same Category -> Inform user and stop.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "This rule already exists for '${widget.categoryName}'!",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      } else {
        // Different Category -> Ask to Move.
        // We need the other category name for context.
        final categories = await DatabaseHelper.instance.getCategories();
        final otherCatName =
            categories.firstWhere(
              (c) => c['id'] == existingCatId,
              orElse: () => {'name': 'Unknown Category'},
            )['name'];

        final shouldMove = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text("Duplicate Rule"),
                content: Text(
                  "The keyword '$keyword' is already assigned to '$otherCatName'.\n\nDo you want to move it to '${widget.categoryName}'?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Move Rule"),
                  ),
                ],
              ),
        );

        if (shouldMove == true) {
          await DatabaseHelper.instance.updateCategoryRule(
            existingRule['id'],
            widget.categoryId,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Rule moved successfully.")),
            );
            // Ask for retroactive apply (common flow below)
          }
        } else {
          return; // Cancelled
        }
      }
    } else {
      // New Rule -> Save normally
      await DatabaseHelper.instance.addCategoryRule(widget.categoryId, keyword);
    }

    // ... rest is same

    if (!mounted) return;

    // Ask to update existing transactions
    bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Apply Retroactively?"),
            content: Text(
              "Do you want to categorize all existing transactions containing '$keyword' as '${widget.categoryName}'?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("No, only new"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Yes, apply to all"),
              ),
            ],
          ),
    );

    if (shouldUpdate == true) {
      final count = await DatabaseHelper.instance
          .applyCategoryRuleToTransactions(widget.categoryId, keyword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Updated $count past transactions.")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rule added for future transactions.")),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context, true); // Return true to indicate update
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no SMS selected, show Picker
    if (_sourceBody == null) {
      if (_isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return SmsListScreen(
        messages: _inboxMessages,
        onSmsSelected: _onSmsPicked,
      );
    }

    // Step 2: Token Selection
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Rule for ${widget.categoryName}"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Go back to picker
            setState(() {
              _sourceBody = null;
              _sourceAddress = null;
              _selectedIndices.clear();
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Tap words to build your Keyword",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Select the Merchant Name or unique identifier (e.g. 'Zomato', 'Apollo Pharma').",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // We reuse SmsCodeBlock.
            SmsCodeBlock(
              tokens: _bodyTokens,
              onTokenTap: _toggleToken,
              selectedAnchorIndices: _selectedIndices,
            ),

            const SizedBox(height: 32),

            // Preview Selection
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: Column(
                children: [
                  const Text(
                    "Selected Keyword:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedIndices.isEmpty
                        ? "(Tap words above)"
                        : _bodyTokens
                            .asMap()
                            .entries
                            .where((e) => _selectedIndices.contains(e.key))
                            .map((e) => e.value)
                            .join(" "),
                  ),
                  if (_selectedIndices.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final sorted = _selectedIndices.toList()..sort();
                        final start = _tokenRanges[sorted.first].start;
                        final end = _tokenRanges[sorted.last].end;
                        // Grab envelope
                        final previewText = _sourceBody!.substring(start, end);

                        return Text(
                          previewText,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.blue,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _selectedIndices.isEmpty ? null : _saveRule,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                "Save Rule",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
