import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../viewmodels/calendar_view_model.dart';
import 'transaction_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarViewModel _viewModel = CalendarViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.init();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  // --- UI Helpers ---

  Color _getDayColor(int day, bool isSelected, bool inRange) {
    Color baseColor = Colors.transparent;

    if (_viewModel.dailyNet.containsKey(day)) {
      final net = _viewModel.dailyNet[day]!;
      double intensity = (net.abs() / _viewModel.maxNet).clamp(0.2, 1.0);
      if (net >= 0) {
        baseColor = AppColors.expense.withValues(alpha: intensity);
      } else {
        baseColor = AppColors.income.withValues(alpha: intensity);
      }
    }

    if (inRange) {
      return Color.alphaBlend(
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        baseColor,
      );
    }
    return baseColor;
  }

  Color _getTextColor(int day, bool isSelected, bool inRange) {
    if (inRange) return Theme.of(context).colorScheme.onSecondary;

    if (_viewModel.dailyNet.containsKey(day)) {
      final net = _viewModel.dailyNet[day]!;
      double intensity = (net.abs() / _viewModel.maxNet).clamp(0.2, 1.0);
      return intensity > 0.5
          ? AppColors.onColoredBackground
          : Theme.of(context).colorScheme.onSurface;
    }
    return Theme.of(context).colorScheme.onSurface;
  }

  String _getRangeHeaderText() {
    if (_viewModel.rangeStart == null) {
      return "Select a date";
    }
    final startStr = DateFormat.yMMMd().format(_viewModel.rangeStart!);
    if (_viewModel.rangeEnd == null) {
      return "Transactions for $startStr";
    }
    final endStr = DateFormat.yMMMd().format(_viewModel.rangeEnd!);
    return "$startStr - $endStr";
  }

  String _getSortLabel() {
    switch (_viewModel.sortOption) {
      case SortOption.dateDesc:
        return CMS.calendar['sort_newest']!;
      case SortOption.dateAsc:
        return CMS.calendar['sort_oldest']!;
      case SortOption.amountDesc:
        return CMS.calendar['sort_amount_high']!;
      case SortOption.amountAsc:
        return CMS.calendar['sort_amount_low']!;
    }
  }

  // --- Filters & Sort UI ---

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
              _buildSortTile(SortOption.dateDesc, CMS.calendar['sort_newest']!),
              _buildSortTile(SortOption.dateAsc, CMS.calendar['sort_oldest']!),
              _buildSortTile(
                SortOption.amountDesc,
                CMS.calendar['sort_amount_high']!,
              ),
              _buildSortTile(
                SortOption.amountAsc,
                CMS.calendar['sort_amount_low']!,
              ),
              const Divider(),
              TextButton(
                onPressed: () {
                  _viewModel.setSortOption(SortOption.dateDesc);
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

  ListTile _buildSortTile(SortOption option, String label) {
    return ListTile(
      leading: Icon(_getSortIcon(option)),
      title: Text(label),
      trailing:
          _viewModel.sortOption == option
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
      onTap: () {
        _viewModel.setSortOption(option);
        Navigator.pop(context);
      },
    );
  }

  IconData _getSortIcon(SortOption option) {
    switch (option) {
      case SortOption.dateDesc:
      case SortOption.dateAsc:
        return Icons.calendar_today;
      case SortOption.amountDesc:
        return Icons.arrow_upward;
      case SortOption.amountAsc:
        return Icons.arrow_downward;
    }
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
                              _viewModel.resetFilters();
                              setModalState(() {});
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
                                _viewModel.allCategories.map((cat) {
                                  final isSelected = _viewModel
                                      .selectedCategoryIds
                                      .contains(cat['id']);
                                  return FilterChip(
                                    label: Text(cat['name']),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      _viewModel.toggleCategoryFilter(
                                        cat['id'],
                                      );
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
                          if (_viewModel.availableSenders.isEmpty)
                            Text(
                              CMS.calendar['no_transactions_month']!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          Wrap(
                            spacing: 8,
                            children:
                                _viewModel.availableSenders.map((sender) {
                                  final isSelected = _viewModel.selectedSenders
                                      .contains(sender);
                                  return FilterChip(
                                    label: Text(sender),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      _viewModel.toggleSenderFilter(sender);
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
                          const SizedBox(height: 48),
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
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        final daysInMonth =
            DateTime(
              _viewModel.focusedDate.year,
              _viewModel.focusedDate.month + 1,
              0,
            ).day;
        final firstDayOfMonth = DateTime(
          _viewModel.focusedDate.year,
          _viewModel.focusedDate.month,
          1,
        );
        final weekdayOffset = firstDayOfMonth.weekday % 7;

        final headerText = _getRangeHeaderText();
        final activeFiltersCount =
            _viewModel.selectedCategoryIds.length +
            _viewModel.selectedSenders.length;

        return Scaffold(
          // backgroundColor: Colors.grey[50], // Removed
          appBar: AppBar(
            title: Text(
              CMS.calendar['title']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            // backgroundColor: Colors.white, // Removed
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed:
                    _viewModel.isLoading ? null : _viewModel.fetchMonthData,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _viewModel.fetchMonthData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Month Navigator
                SliverToBoxAdapter(
                  child: Container(
                    color: Theme.of(context).cardTheme.color,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _viewModel.changeMonth(-1),
                        ),
                        Text(
                          DateFormat.yMMMM().format(_viewModel.focusedDate),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _viewModel.changeMonth(1),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Weekday Headers
                SliverToBoxAdapter(
                  child: Container(
                    color: Theme.of(context).cardTheme.color,
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
                if (_viewModel.isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(8),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1.0,
                            crossAxisSpacing: 0,
                            mainAxisSpacing: 0,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index < weekdayOffset) {
                          return const SizedBox.shrink();
                        }

                        final day = index - weekdayOffset + 1;
                        if (day > daysInMonth) return const SizedBox.shrink();

                        final date = DateTime(
                          _viewModel.focusedDate.year,
                          _viewModel.focusedDate.month,
                          day,
                        );

                        final isStart = _viewModel.isStart(date);
                        final isEnd = _viewModel.isEnd(date);
                        final isRangeStart = isStart;
                        final isRangeEnd =
                            isEnd ||
                            (_viewModel.rangeStart != null &&
                                _viewModel.rangeEnd == null &&
                                isStart);

                        final inRange = _viewModel.isInRange(date);
                        final isSelected =
                            isRangeStart || isRangeEnd || inRange;

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

                        double leftMargin = 2;
                        double rightMargin = 2;
                        double topMargin = 2;
                        double bottomMargin = 2;

                        if (isSelected) {
                          if (!isRangeStart && !isRowStart) {
                            leftMargin = 0;
                          }
                          if (!isRangeEnd && !isRowEnd) {
                            rightMargin = 0;
                          }
                        }

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

                        BoxBorder? border;
                        if (isSelected) {
                          border = Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2,
                            ),
                            bottom: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2,
                            ),
                            left:
                                (isRangeStart || isRowStart)
                                    ? BorderSide(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      width: 2,
                                    )
                                    : BorderSide.none,
                            right:
                                (isRangeEnd || isRowEnd)
                                    ? BorderSide(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                      width: 2,
                                    )
                                    : BorderSide.none,
                          );
                        } else {
                          border = Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.2),
                            width: 0.5,
                          );
                        }

                        return GestureDetector(
                          onTap: () => _viewModel.onDaySelected(date),
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

                if (!_viewModel.isLoading) ...[
                  const SliverToBoxAdapter(child: Divider(height: 1)),

                  // 4. Header with Reset Logic
                  SliverToBoxAdapter(
                    child: Container(
                      color: Theme.of(context).cardTheme.color,
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
                          if (_viewModel.rangeStart != null)
                            TextButton(
                              onPressed: _viewModel.resetDate,
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
                      color: Theme.of(context).cardTheme.color,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showSortOptions,
                            icon: const Icon(Icons.sort, size: 16),
                            label: Text(_getSortLabel()),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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

                  // 6. Active Filters Chips
                  if (activeFiltersCount > 0)
                    SliverToBoxAdapter(
                      child: Container(
                        color: Theme.of(context).cardTheme.color,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            ..._viewModel.selectedCategoryIds.map((id) {
                              final name =
                                  _viewModel.allCategories.firstWhere(
                                    (c) => c['id'] == id,
                                    orElse: () => {'name': 'Unknown'},
                                  )['name'];
                              return Chip(
                                label: Text(name),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  _viewModel.toggleCategoryFilter(id);
                                },
                                backgroundColor: Colors.blue.shade50,
                                labelStyle: TextStyle(
                                  color: Colors.blue.shade900,
                                ),
                              );
                            }),
                            ..._viewModel.selectedSenders.map((s) {
                              return Chip(
                                label: Text(s),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  _viewModel.toggleSenderFilter(s);
                                },
                                backgroundColor: Colors.green.shade50,
                                labelStyle: TextStyle(
                                  color: Colors.green.shade900,
                                ),
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
      },
    );
  }

  Widget _buildTransactionSliver() {
    // This is now purely UI rendering logic; actual filtering happens in VM
    final txs = _viewModel.getTransactionsInRange();

    if (txs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text(
              CMS.calendar['no_transactions_month']!, // Or a generic "none found" msg
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
                        ? AppColors.incomeBackground
                        : AppColors.expenseBackground,
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: isCredit ? AppColors.income : AppColors.expense,
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
                  color: isCredit ? AppColors.income : AppColors.expense,
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
                _viewModel.fetchMonthData(); // Refresh on return
              },
            ),
            const Divider(height: 1),
          ],
        );
      }, childCount: txs.length),
    );
  }
}
