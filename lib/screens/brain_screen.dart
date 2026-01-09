import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import '../services/database_helper.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/cms.dart';
import 'sms_setup_screen.dart';
import 'sms_list_screen.dart';
import 'teach_pattern_screen.dart';
import 'teach_rule_screen.dart';

class BrainScreen extends StatefulWidget {
  final String? initialBody;
  final String? initialSender;

  final int? initialCategoryId;

  const BrainScreen({
    super.key,
    this.initialBody,
    this.initialSender,
    this.initialCategoryId,
  });

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends State<BrainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- My Rules Tab State ---
  List<Map<String, dynamic>> _allRules = [];
  bool _isLoadingRules = true;
  int? _filterCategoryId; // For filtering My Rules

  // --- Patterns Tab State ---
  List<Map<String, dynamic>> _allPatterns = [];
  bool _isLoadingPatterns = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {}); // Rebuild FAB on tab change
    });
    // Check initial tab
    if (widget.initialCategoryId != null) {
      _filterCategoryId = widget.initialCategoryId;
      // Animate to Rules tab after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(1);
      });
    }

    _loadRules();
    _loadPatterns();

    // If initialBody provided, navigate to Teach Screen immediately
    if (widget.initialBody != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => TeachRuleScreen(
                  initialBody: widget.initialBody,
                  initialSender: widget.initialSender,
                  initialCategoryId: widget.initialCategoryId,
                ),
          ),
        ).then((val) {
          if (val == true) {
            _loadRules();
            _tabController.animateTo(1); // Go to Rules tab
          }
        });
      });
    }
  }

  // --- Shared Logic ---

  // Rule saving moved to TeachRuleScreen, but we need load logic here.

  // --- My Rules Tab Logic ---

  Future<void> _loadRules() async {
    final rules = await DatabaseHelper.instance.getAllCategoryRules();
    // We need category names too
    final cats = await DatabaseHelper.instance.getCategories();
    final catMap = {for (var c in cats) c['id']: c};

    final enrichedRules =
        rules.map((r) {
          final cat = catMap[r['categoryId']];
          return {
            ...r,
            'categoryName': cat?['name'] ?? 'Unknown',
            'categoryColor': cat?['color'] ?? 0xFF9E9E9E,
          };
        }).toList();

    setState(() {
      _allRules = enrichedRules;
      _isLoadingRules = false;
    });
  }

  Future<void> _deleteRule(int id, String keyword) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.brain['delete_rule_title']),
            content: Text(
              CMS.brain['delete_rule_content'].replaceAll('{keyword}', keyword),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(CMS.common['cancel']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(CMS.common['delete']!),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteCategoryRule(id);
      _loadRules();
    }
  }

  // --- Patterns Tab Logic ---

  Future<void> _loadPatterns() async {
    final db = await DatabaseHelper.instance.database;
    final patterns = await db.query('patterns');
    if (mounted) {
      setState(() {
        _allPatterns = patterns;
        _isLoadingPatterns = false;
      });
    }
  }

  Future<void> _deletePattern(int id) async {
    final shouldDeleteTransactions = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.settings['delete_pattern_title']!),
            content: Text(CMS.settings['delete_pattern_content']!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null), // Cancel
                child: Text(CMS.common['cancel']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // Keep Transactions
                child: Text(CMS.settings['keep_transactions_btn']!),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true), // Delete All
                style: TextButton.styleFrom(foregroundColor: AppColors.delete),
                child: Text(CMS.settings['delete_all_btn']!),
              ),
            ],
          ),
    );

    if (shouldDeleteTransactions == null) return;

    await DatabaseHelper.instance.deletePattern(
      id,
      deleteTransactions: shouldDeleteTransactions,
    );
    _loadPatterns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(CMS.brain['title']!),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: CMS.brain['patterns_tab'] ?? 'Message Patterns'),
            Tab(text: CMS.brain['rules_tab'] ?? 'Category Rules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPatternsTab(), _buildRulesTab()],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildFab() {
    final isPatternsTab = _tabController.index == 0;

    return FloatingActionButton.extended(
      onPressed: () {
        if (isPatternsTab) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SmsSetupScreen()),
          ).then((_) => _loadPatterns());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TeachRuleScreen()),
          ).then((val) {
            if (val == true) _loadRules();
          });
        }
      },
      icon: Icon(isPatternsTab ? Icons.add : Icons.school),
      label: Text(
        isPatternsTab
            ? 'New Pattern'
            : (CMS.brain['teach_fab_label'] ?? 'New Rule'),
      ),
    );
  }

  // --- UI Builders ---

  Widget _buildPatternsTab() {
    if (_isLoadingPatterns) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allPatterns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(CMS.settings['no_patterns'] ?? 'No patterns found.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Pattern'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmsSetupScreen(),
                  ),
                ).then((_) => _loadPatterns());
              },
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: _allPatterns.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final p = _allPatterns[i];
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              p['name'] ?? "Unnamed",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                p['senderId'],
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final telephony = Telephony.instance;
                    bool? permissionsGranted =
                        await telephony.requestPhoneAndSmsPermissions;

                    if (permissionsGranted != true && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'SMS permission required to edit logic',
                          ),
                        ),
                      );
                      return;
                    }

                    // 1. Try fetching by Sender ID
                    List<SmsMessage> messages = await telephony.getInboxSms(
                      columns: [
                        SmsColumn.ADDRESS,
                        SmsColumn.BODY,
                        SmsColumn.DATE,
                      ],
                      filter: SmsFilter.where(
                        SmsColumn.ADDRESS,
                      ).like("%${p['senderId']}%"),
                      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
                    );

                    if (!mounted) return;

                    // 2. Logic to open SMS List
                    void openSmsList(List<SmsMessage> msgs) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => SmsListScreen(
                                messages: msgs,
                                onSmsSelected: (SmsMessage selectedMsg) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => TeachPatternScreen(
                                            message: selectedMsg,
                                            existingPatternId: p['id'],
                                            initialPatternName: p['name'],
                                          ),
                                    ),
                                  ).then((_) {
                                    // Pop SmsListScreen after returning from Teach
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      _loadPatterns();
                                    }
                                  });
                                },
                              ),
                        ),
                      );
                    }

                    if (messages.isNotEmpty) {
                      // Found messages for this sender, show them
                      openSmsList(messages);
                    } else {
                      // 3. No messages found, ask to scan ALL
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text("No Messages Found"),
                              content: Text(
                                "No messages found for sender '${p['senderId']}'. Would you like to scan your entire inbox to find a message to teach this pattern?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    // Fetch ALL
                                    final allMessages = await telephony
                                        .getInboxSms(
                                          columns: [
                                            SmsColumn.ADDRESS,
                                            SmsColumn.BODY,
                                            SmsColumn.DATE,
                                          ],
                                          sortOrder: [
                                            OrderBy(
                                              SmsColumn.DATE,
                                              sort: Sort.DESC,
                                            ),
                                          ],
                                        );
                                    if (!mounted) return;
                                    openSmsList(allMessages);
                                  },
                                  child: const Text("Scan All"),
                                ),
                              ],
                            ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _deletePattern(p['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRulesTab() {
    if (_isLoadingRules) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter Logic
    final filteredRules =
        _filterCategoryId == null
            ? _allRules
            : _allRules
                .where((r) => r['categoryId'] == _filterCategoryId)
                .toList();

    return Column(
      children: [
        // Filter Chips
        FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper.instance.getCategories(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final cats = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text("All"),
                    selected: _filterCategoryId == null,
                    onSelected:
                        (selected) => setState(() => _filterCategoryId = null),
                  ),
                  const SizedBox(width: 8),
                  ...cats.map((cat) {
                    final isSelected = _filterCategoryId == cat['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat['name']),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(
                            () =>
                                _filterCategoryId = selected ? cat['id'] : null,
                          );
                        },
                        avatar:
                            isSelected
                                ? null
                                : Icon(
                                  Icons.circle,
                                  color: Color(cat['color']),
                                  size: 10,
                                ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),

        // Rules List
        Expanded(
          child:
              filteredRules.isEmpty
                  ? Center(
                    child: Text(
                      _filterCategoryId == null
                          ? CMS.brain['no_rules']
                          : "No rules for this category.",
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: filteredRules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final rule = filteredRules[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            rule['keyword'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      rule['categoryColor'],
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    rule['categoryName'],
                                    style: TextStyle(
                                      color: Color(rule['categoryColor']),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed:
                                () => _deleteRule(rule['id'], rule['keyword']),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
