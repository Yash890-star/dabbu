import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../services/database_helper.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/cms.dart';
import '../widgets/sms/sms_code_block.dart';
import 'sms_list_screen.dart';

class TeachRuleScreen extends StatefulWidget {
  final String? initialBody;
  final String? initialSender;
  final int? initialCategoryId;

  const TeachRuleScreen({
    super.key,
    this.initialBody,
    this.initialSender,
    this.initialCategoryId,
  });

  @override
  State<TeachRuleScreen> createState() => _TeachRuleScreenState();
}

class _TeachRuleScreenState extends State<TeachRuleScreen> {
  // --- State ---
  String? _sourceBody;
  List<SmsMessage> _inboxMessages = [];
  bool _isLoadingInbox = false;
  List<String> _bodyTokens = [];
  List<TextRange> _tokenRanges = [];
  Set<int> _selectedIndices = {};
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    if (widget.initialBody != null) {
      _onManualDataLoaded(widget.initialBody!, widget.initialSender);
    }
  }

  void _onManualDataLoaded(String body, String? sender) {
    _populateTokens(body);
    setState(() {
      _sourceBody = body;
    });
  }

  Future<void> _fetchInbox() async {
    setState(() => _isLoadingInbox = true);
    final Telephony telephony = Telephony.instance;
    try {
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      if (permissionsGranted != true) {
        if (mounted) {
          setState(() => _isLoadingInbox = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission denied')),
          );
        }
        return;
      }

      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      if (mounted) {
        if (messages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No SMS messages found')),
          );
        }
        setState(() {
          _inboxMessages = messages;
          _isLoadingInbox = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading SMS: $e");
      if (mounted) {
        setState(() => _isLoadingInbox = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading SMS: $e')));
      }
    }
  }

  void _onSmsPicked(SmsMessage msg) {
    if (msg.body == null) return;
    _populateTokens(msg.body!);
    setState(() {
      _sourceBody = msg.body;
      _selectedIndices = {};
    });
  }

  void _populateTokens(String body) {
    final List<String> tokens = [];
    final List<TextRange> ranges = [];
    final regExp = RegExp(r"[^ \s/,\-]+");
    final matches = regExp.allMatches(body);

    for (var m in matches) {
      tokens.add(m.group(0)!);
      ranges.add(TextRange(start: m.start, end: m.end));
    }

    setState(() {
      _bodyTokens = tokens;
      _tokenRanges = ranges;
    });
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

  String? _getSelectedKeyword() {
    if (_selectedIndices.isEmpty || _sourceBody == null) return null;
    final sortedIndices = _selectedIndices.toList()..sort();
    final firstIndex = sortedIndices.first;
    final lastIndex = sortedIndices.last;
    final startChar = _tokenRanges[firstIndex].start;
    final endChar = _tokenRanges[lastIndex].end;
    return _sourceBody!.substring(startChar, endChar);
  }

  Future<void> _saveRule() async {
    final keyword = _getSelectedKeyword();
    if (keyword == null || _selectedCategoryId == null) return;

    // Check Duplicate
    final existingRule = await DatabaseHelper.instance.getRuleByKeyword(
      keyword,
    );
    if (existingRule != null) {
      if (!mounted) return;
      final override = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("Rule Exists"),
              content: Text("A rule for '$keyword' already exists. Overwrite?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Overwrite"),
                ),
              ],
            ),
      );
      if (override != true) return;

      await DatabaseHelper.instance.updateCategoryRule(
        existingRule['id'],
        _selectedCategoryId!,
      );
    } else {
      await DatabaseHelper.instance.addCategoryRule(
        _selectedCategoryId!,
        keyword,
      );
    }

    // Retroactive Apply Logic
    if (!mounted) return;
    bool? shouldUpdate = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Apply Retroactively?"),
            content: Text(
              "Categorize all past transactions with '$keyword' too?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("No"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Yes"),
              ),
            ],
          ),
    );

    if (shouldUpdate == true) {
      await DatabaseHelper.instance.applyCategoryRuleToTransactions(
        _selectedCategoryId!,
        keyword,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Rule Saved!")));
      Navigator.pop(context, true); // Return success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teach Rule")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. teaching UI if source selected
    if (_sourceBody != null) {
      return _buildTeachingUi();
    }

    // 2. Loading state
    if (_isLoadingInbox) {
      return const Center(child: CircularProgressIndicator());
    }

    // 3. List picker if messages found
    if (_inboxMessages.isNotEmpty) {
      return SmsListScreen(
        messages: _inboxMessages,
        onSmsSelected: _onSmsPicked,
      );
    }

    // 4. Default empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.school_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            CMS.brain['intro_bubble'] ?? 'Ready to learn!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchInbox,
            icon: const Icon(Icons.sms),
            label: const Text("Pick from SMS"),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachingUi() {
    final keyword = _getSelectedKeyword();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBotBubble(CMS.brain['intro_bubble'] ?? 'Intro'),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surface,
            ),
            padding: const EdgeInsets.all(16),
            child: SmsCodeBlock(
              tokens: _bodyTokens,
              onTokenTap: _toggleToken,
              selectedAnchorIndices: _selectedIndices,
            ),
          ),
          const SizedBox(height: 16),
          if (keyword != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(
                  (CMS.brain['keyword_prompt'] ?? 'Contains "{keyword}"')
                      .replaceAll('{keyword}', keyword),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildBotBubble(
              (CMS.brain['category_bubble'] ?? 'Category for "{keyword}"?')
                  .replaceAll('{keyword}', keyword),
            ),
            const SizedBox(height: 24),
            Text(
              CMS.brain['step_category'] ?? 'Category',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 12),
            _buildCategoryGrid(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedCategoryId == null ? null : _saveRule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  CMS.brain['save_btn'] ?? 'Save',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotBubble(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.primary,
          radius: 16,
          child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(text, style: const TextStyle(height: 1.4)),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final cats = snapshot.data!;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: cats.length,
          itemBuilder: (ctx, i) {
            final cat = cats[i];
            final isSelected = _selectedCategoryId == cat['id'];
            final color = Color(cat['color']);

            return InkWell(
              onTap: () => setState(() => _selectedCategoryId = cat['id']),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? color.withValues(alpha: 0.2)
                          : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle, color: color, size: 12),
                    const SizedBox(width: 8),
                    Text(
                      cat['name'],
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check, size: 16, color: color),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
