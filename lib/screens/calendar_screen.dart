import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../utils/cms.dart';
import 'transaction_detail_screen.dart';

enum SortOption { dateDesc, dateAsc, amountDesc, amountAsc }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDate = DateTime.now();

  // Range Selection State
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // Data for the month
  Map<int, double> _dailyNet = {}; // Day -> Net Amount (Debit - Credit)
  Map<int, List<Map<String, dynamic>>> _dailyTransactions = {};
  double _maxNet = 1.0; // For scaling opacity

  // Filter/Sort State
  SortOption _sortOption = SortOption.dateDesc;
  final List<int> _selectedCategoryIds = [];
  final List<String> _selectedSenders = [];

  // Available Data for Filters
  List<Map<String, dynamic>> _allCategories = [];
  Set<String> _availableSenders = {}; // Senders found in current month

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Default to today as a single date selection
    _rangeStart = DateTime.now();
    _initData();
  }

  Future<void> _initData() async {
    await _fetchCategories();
    await _fetchMonthData();
  }

  Future<void> _fetchCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    if (mounted) {
      setState(() {
        _allCategories = cats;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedDate = DateTime(
        _focusedDate.year,
        _focusedDate.month + offset,
        1,
      );
      // Reset range when changing months?
      // Let's keep the selection if it's within view, but usually simplest to reset or keep state.
      // For now, let's NOT clear selection, so users can see previous month's selection if they switch back.
      // But if we want to default to 1st of new month:
      // _rangeStart = _focusedDate; _rangeEnd = null;
    });
    _fetchMonthData();
  }

  Future<void> _fetchMonthData() async {
    setState(() => _isLoading = true);

    final start = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final end = DateTime(
      _focusedDate.year,
      _focusedDate.month + 1,
      0,
      23,
      59,
      59,
    );

    final data = await DatabaseHelper.instance.getFilteredTransactions(
      startEpoch: start.millisecondsSinceEpoch,
      endEpoch: end.millisecondsSinceEpoch,
    );

    // Process Data
    Map<int, double> tempNet = {};
    Map<int, List<Map<String, dynamic>>> tempTxs = {};
    double tempMax = 0;
    Set<String> senders = {};

    for (var tx in data) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      final day = date.day;
      final amount = (tx['amount'] as num).toDouble();
      final isDebit = tx['type'] == 'debit';

      // Collect Sender/Pattern Name for Filters
      final name = tx['patternName'] ?? tx['sender'] ?? "Unknown";
      senders.add(name);

      // Aggregate Net
      // Net = Debit - Credit.
      double currentNet = tempNet[day] ?? 0.0;
      if (isDebit) {
        currentNet += amount;
      } else {
        currentNet -= amount;
      }
      tempNet[day] = currentNet;

      // Track Max for Opacity (using absolute value)
      if (currentNet.abs() > tempMax) {
        tempMax = currentNet.abs();
      }

      // Store Transaction
      if (tempTxs[day] == null) tempTxs[day] = [];
      tempTxs[day]!.add(tx);
    }

    if (mounted) {
      setState(() {
        _dailyNet = tempNet;
        _dailyTransactions = tempTxs;
        _maxNet = tempMax == 0 ? 1.0 : tempMax; // Avoid division by zero
        _availableSenders = senders;
        _isLoading = false;
      });
    }
  }

  // --- Logic Helpers ---

  // Check if a day is the Start date
  bool _isStart(DateTime date) {
    return _rangeStart != null &&
        date.year == _rangeStart!.year &&
        date.month == _rangeStart!.month &&
        date.day == _rangeStart!.day;
  }

  // Check if a day is the End date
  bool _isEnd(DateTime date) {
    return _rangeEnd != null &&
        date.year == _rangeEnd!.year &&
        date.month == _rangeEnd!.month &&
        date.day == _rangeEnd!.day;
  }

  // Check if a day is inside the range (exclusive of start/end)
  bool _isInRange(DateTime date) {
    if (_rangeStart == null || _rangeEnd == null) return false;
    // Normalize to midnight for comparison
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day);
    final e = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day);
    return d.isAfter(s) && d.isBefore(e);
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      if (_rangeStart == null) {
        // Case 0: No selection -> Select Start
        _rangeStart = date;
        _rangeEnd = null;
      } else if (_rangeEnd == null) {
        // Case 1: Start exists, End doesn't
        if (date.isBefore(_rangeStart!)) {
          // If tapping before start, New Start
          _rangeStart = date;
        } else if (date.isAtSameMomentAs(_rangeStart!) ||
            (date.year == _rangeStart!.year &&
                date.month == _rangeStart!.month &&
                date.day == _rangeStart!.day)) {
          // Tapping same day -> Deselect or Keep?
          // Let's keep it as single selection.
          _rangeEnd = null;
        } else {
          // After start -> Set End
          _rangeEnd = date;
        }
      } else {
        // Case 2: Range already exists -> Reset to new Start
        _rangeStart = date;
        _rangeEnd = null;
      }
    });
  }

  Color _getDayColor(int day, bool isSelected, bool inRange) {
    Color baseColor = Colors.white;

    // 1. Determine Base Heat Map Color
    if (_dailyNet.containsKey(day)) {
      final net = _dailyNet[day]!;
      double intensity = (net.abs() / _maxNet).clamp(0.2, 1.0);
      if (net >= 0) {
        baseColor = Colors.red.withOpacity(intensity);
      } else {
        baseColor = Colors.green.withOpacity(intensity);
      }
    }

    // 2. Apply Selection Tint
    // If inRange (middle), tint it slightly blue
    if (inRange) {
      // Blend baseColor with a light blue overlay
      return Color.alphaBlend(Colors.blue.withOpacity(0.2), baseColor);
    }

    // Start/End are just the base color (the border indicates selection)
    return baseColor;
  }

  Color _getTextColor(int day, bool isSelected, bool inRange) {
    // If in range (blue background), black text
    if (inRange) return Colors.black87;

    // If heatmap data exists
    if (_dailyNet.containsKey(day)) {
      final net = _dailyNet[day]!;
      double intensity = (net.abs() / _maxNet).clamp(0.2, 1.0);
      // If intensity is high (dark background), white text
      return intensity > 0.5 ? Colors.white : Colors.black87;
    }

    // Default
    return Colors.black87;
  }

  // --- Filtering & Sorting UI ---

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  CMS.calendar['sort_title']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(CMS.calendar['sort_newest']!),
                trailing:
                    _sortOption == SortOption.dateDesc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  setState(() => _sortOption = SortOption.dateDesc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(CMS.calendar['sort_oldest']!),
                trailing:
                    _sortOption == SortOption.dateAsc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  setState(() => _sortOption = SortOption.dateAsc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: Text(CMS.calendar['sort_amount_high']!),
                trailing:
                    _sortOption == SortOption.amountDesc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  setState(() => _sortOption = SortOption.amountDesc);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: Text(CMS.calendar['sort_amount_low']!),
                trailing:
                    _sortOption == SortOption.amountAsc
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                onTap: () {
                  setState(() => _sortOption = SortOption.amountAsc);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              TextButton(
                onPressed: () {
                  setState(() => _sortOption = SortOption.dateDesc);
                  Navigator.pop(context);
                },
                child: Text(CMS.calendar['reset_sort']!),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            CMS.calendar['filter_title']!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Reset logic
                              setState(() {
                                _selectedCategoryIds.clear();
                                _selectedSenders.clear();
                              });
                              setModalState(() {}); // Refresh modal
                            },
                            child: Text(CMS.calendar['reset_all']!),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Text(
                            CMS.calendar['categories_header']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children:
                                _allCategories.map((cat) {
                                  final isSelected = _selectedCategoryIds
                                      .contains(cat['id']);
                                  return FilterChip(
                                    label: Text(cat['name']),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      // Update Parent State immediately
                                      setState(() {
                                        if (selected) {
                                          _selectedCategoryIds.add(cat['id']);
                                        } else {
                                          _selectedCategoryIds.remove(
                                            cat['id'],
                                          );
                                        }
                                      });
                                      // Update Modal State to reflect change
                                      setModalState(() {});
                                    },
                                    backgroundColor: Colors.grey.shade100,
                                    selectedColor: Colors.blue.shade100,
                                    labelStyle: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.blue.shade900
                                              : Colors.black87,
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            CMS.calendar['senders_header']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_availableSenders.isEmpty)
                            Text(
                              CMS.calendar['no_transactions_month']!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          Wrap(
                            spacing: 8,
                            children:
                                _availableSenders.map((sender) {
                                  final isSelected = _selectedSenders.contains(
                                    sender,
                                  );
                                  return FilterChip(
                                    label: Text(sender),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedSenders.add(sender);
                                        } else {
                                          _selectedSenders.remove(sender);
                                        }
                                      });
                                      setModalState(() {});
                                    },
                                    backgroundColor: Colors.grey.shade100,
                                    selectedColor: Colors.green.shade100,
                                    labelStyle: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.green.shade900
                                              : Colors.black87,
                                    ),
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 48), // Bottom padding
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    // Adjust logic for starting on Sunday (0) vs Monday (1)
    // DateTime.weekday: Mon=1 ... Sun=7.
    // We want Sunday col 0.
    // If 1st is Mon(1), offset is 1. If Sun(7), offset is 0.
    final weekdayOffset = firstDayOfMonth.weekday % 7;

    final headerText = _getRangeHeaderText();
    final activeFiltersCount =
        _selectedCategoryIds.length + _selectedSenders.length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          CMS.calendar['title']!,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _initData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Month Navigator
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Text(
                      DateFormat.yMMMM().format(_focusedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Weekday Headers
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children:
                      ["S", "M", "T", "W", "T", "F", "S"]
                          .map(
                            (d) => Text(
                              d,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ),

            // 3. Calendar Grid
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 0, // Zero spacing to allow merging
                    mainAxisSpacing: 0,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index < weekdayOffset) return const SizedBox.shrink();

                    final day = index - weekdayOffset + 1;
                    if (day > daysInMonth) return const SizedBox.shrink();

                    final date = DateTime(
                      _focusedDate.year,
                      _focusedDate.month,
                      day,
                    );

                    final isStart = _isStart(date);
                    final isEnd = _isEnd(date);
                    // Treat single day selection as a "Start"
                    final isRangeStart = isStart;
                    final isRangeEnd =
                        isEnd ||
                        (_rangeStart != null && _rangeEnd == null && isStart);

                    final inRange = _isInRange(date);
                    final isSelected = isRangeStart || isRangeEnd || inRange;

                    // Row Position Logic (Sun=0...Sat=6 in standard grid, but index based)
                    // Grid index 0 is first cell.
                    // We need to know if it's the start/end of a ROW in the grid.
                    final colIndex = index % 7;
                    final isRowStart = colIndex == 0;
                    final isRowEnd = colIndex == 6;

                    final bgColor = _getDayColor(
                      day,
                      isRangeStart || isRangeEnd,
                      inRange,
                    );
                    final textColor = _getTextColor(
                      day,
                      isRangeStart || isRangeEnd,
                      inRange,
                    );

                    // Dynamic Margin to simulate spacing
                    // We want 2px margin on all sides conceptually to get 4px gaps.
                    // For connected range items, we remove horizontal margin between them.

                    double leftMargin = 2;
                    double rightMargin = 2;
                    double topMargin = 2;
                    double bottomMargin = 2;

                    if (isSelected) {
                      // If connected to left (i.e. not start of range AND not start of row)
                      // Note: _isInRange is exclusive.
                      // Left neighbor exists in range if:
                      // we are NOT rangeStart AND not rowStart.
                      if (!isRangeStart && !isRowStart) {
                        leftMargin = 0;
                      }
                      // If connected to right
                      if (!isRangeEnd && !isRowEnd) {
                        rightMargin = 0;
                      }
                    }

                    // Border Radius
                    // Round outer corners of the strip
                    final radius = BorderRadius.only(
                      topLeft:
                          (isRangeStart || isRowStart) && isSelected
                              ? const Radius.circular(12)
                              : Radius.zero,
                      bottomLeft:
                          (isRangeStart || isRowStart) && isSelected
                              ? const Radius.circular(12)
                              : Radius.zero,
                      topRight:
                          (isRangeEnd || isRowEnd) && isSelected
                              ? const Radius.circular(12)
                              : Radius.zero,
                      bottomRight:
                          (isRangeEnd || isRowEnd) && isSelected
                              ? const Radius.circular(12)
                              : Radius.zero,
                    );

                    // Border Sides
                    // If selected, we draw borders.
                    // Internal boundaries (where margin is 0) should have NO border.
                    BoxBorder? border;
                    if (isSelected) {
                      border = Border(
                        top: const BorderSide(color: Colors.black, width: 2),
                        bottom: const BorderSide(color: Colors.black, width: 2),
                        left:
                            (isRangeStart || isRowStart)
                                ? const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                )
                                : BorderSide.none,
                        right:
                            (isRangeEnd || isRowEnd)
                                ? const BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                )
                                : BorderSide.none,
                      );
                    } else {
                      // Unselected: standard heatmap look (maybe subtle border)
                      border = Border.all(
                        color: Colors.grey.shade200,
                        width: 0.5,
                      );
                    }

                    return GestureDetector(
                      onTap: () => _onDaySelected(date),
                      child: Container(
                        margin: EdgeInsets.fromLTRB(
                          leftMargin,
                          topMargin,
                          rightMargin,
                          bottomMargin,
                        ),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: radius,
                          border: border,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "$day",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }, childCount: daysInMonth + weekdayOffset),
                ),
              ),

            if (!_isLoading) ...[
              const SliverToBoxAdapter(child: Divider(height: 1)),

              // 4. Header with Reset Logic
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        headerText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_rangeStart != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _rangeStart = DateTime.now();
                              _rangeEnd = null;
                            });
                          },
                          child: Text(
                            CMS.calendar['reset_date']!,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 5. Controls Row (Sort/Filter)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Sort Button
                      OutlinedButton.icon(
                        onPressed: _showSortOptions,
                        icon: const Icon(Icons.sort, size: 16),
                        label: Text(_getSortLabel()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter Button
                      OutlinedButton.icon(
                        onPressed: _showFilterOptions,
                        icon: Icon(
                          Icons.filter_list,
                          size: 16,
                          color:
                              activeFiltersCount > 0
                                  ? Colors.blue
                                  : Colors.black87,
                        ),
                        label: Text(
                          activeFiltersCount > 0
                              ? (CMS.calendar['filters_btn'] as String)
                                  .replaceFirst(
                                    '{count}',
                                    activeFiltersCount.toString(),
                                  )
                              : CMS.calendar['filter_btn']!,
                          style: TextStyle(
                            color:
                                activeFiltersCount > 0
                                    ? Colors.blue
                                    : Colors.black87,
                            fontWeight:
                                activeFiltersCount > 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          side: BorderSide(
                            color:
                                activeFiltersCount > 0
                                    ? Colors.blue
                                    : Colors.grey.shade400,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Active Filters Chips (if any)
              if (activeFiltersCount > 0)
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ..._selectedCategoryIds.map((id) {
                          final name =
                              _allCategories.firstWhere(
                                (c) => c['id'] == id,
                                orElse: () => {'name': 'Unknown'},
                              )['name'];
                          return Chip(
                            label: Text(name),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedCategoryIds.remove(id);
                              });
                            },
                            backgroundColor: Colors.blue.shade50,
                            labelStyle: TextStyle(color: Colors.blue.shade900),
                          );
                        }),
                        ..._selectedSenders.map((s) {
                          return Chip(
                            label: Text(s),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _selectedSenders.remove(s);
                              });
                            },
                            backgroundColor: Colors.green.shade50,
                            labelStyle: TextStyle(color: Colors.green.shade900),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // 7. Transaction List
              _buildTransactionSliver(),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortOption) {
      case SortOption.dateDesc:
        return "Newest";
      case SortOption.dateAsc:
        return "Oldest";
      case SortOption.amountDesc:
        return "Amt High-Low";
      case SortOption.amountAsc:
        return "Amt Low-High";
    }
  }

  String _getRangeHeaderText() {
    if (_rangeStart == null) return "Select a date";
    final startStr = DateFormat.yMMMd().format(_rangeStart!);
    if (_rangeEnd == null) return "Transactions for $startStr";
    final endStr = DateFormat.yMMMd().format(_rangeEnd!);
    return "$startStr - $endStr";
  }

  Widget _buildTransactionSliver() {
    final txs = _getTransactionsInRange(); // Now filters and sorts

    if (txs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text(
              "No transactions found.",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final tx = txs[index];
        final isCredit = tx['type'] == 'credit';
        final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);

        return Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                backgroundColor:
                    isCredit
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              title: Text(tx['patternName'] ?? tx['sender'] ?? "Unknown"),
              subtitle: Text(
                "${DateFormat.MMMEd().format(date)} • ${tx['categoryName'] ?? 'Uncategorized'}",
              ),
              trailing: Text(
                "${tx['amount']}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => TransactionDetailScreen(transaction: tx),
                  ),
                );
                _fetchMonthData(); // Refresh
              },
            ),
            const Divider(height: 1),
          ],
        );
      }, childCount: txs.length),
    );
  }

  List<Map<String, dynamic>> _getTransactionsInRange() {
    List<Map<String, dynamic>> allTxs = [];

    if (_rangeStart == null) return [];

    // 1. Gather Transactions
    if (_rangeEnd == null) {
      if (_dailyTransactions.containsKey(_rangeStart!.day)) {
        allTxs.addAll(_dailyTransactions[_rangeStart!.day]!);
      }
    } else {
      DateTime current = DateTime(
        _rangeStart!.year,
        _rangeStart!.month,
        _rangeStart!.day,
      );
      DateTime end = DateTime(
        _rangeEnd!.year,
        _rangeEnd!.month,
        _rangeEnd!.day,
      );

      // Safety
      if (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        while (!current.isAfter(end)) {
          // Only if matches focused month (limitation of data loading)
          if (current.month == _focusedDate.month &&
              current.year == _focusedDate.year) {
            final day = current.day;
            if (_dailyTransactions.containsKey(day)) {
              allTxs.addAll(_dailyTransactions[day]!);
            }
          }
          current = current.add(const Duration(days: 1));
        }
      }
    }

    // 2. Filter
    if (_selectedCategoryIds.isNotEmpty || _selectedSenders.isNotEmpty) {
      allTxs =
          allTxs.where((tx) {
            // Category Filter
            if (_selectedCategoryIds.isNotEmpty) {
              if (!_selectedCategoryIds.contains(tx['categoryId'])) {
                return false;
              }
            }
            // Sender Filter (Match either patternName or sender)
            if (_selectedSenders.isNotEmpty) {
              final name = tx['patternName'] ?? tx['sender'] ?? "Unknown";
              if (!_selectedSenders.contains(name)) {
                return false;
              }
            }
            return true;
          }).toList();
    }

    // 3. Sort
    allTxs.sort((a, b) {
      switch (_sortOption) {
        case SortOption.dateDesc:
          return (b['date'] as int).compareTo(a['date'] as int);
        case SortOption.dateAsc:
          return (a['date'] as int).compareTo(b['date'] as int);
        case SortOption.amountDesc:
          return (b['amount'] as num).compareTo(a['amount'] as num);
        case SortOption.amountAsc:
          return (a['amount'] as num).compareTo(b['amount'] as num);
      }
    });

    return allTxs;
  }
}
