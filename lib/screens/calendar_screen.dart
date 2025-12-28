import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../viewmodels/calendar_view_model.dart';
import 'transaction_detail_screen.dart';
import '../widgets/calendar/heatmap_block.dart';
import '../widgets/calendar/day_summary_block.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/fade_in_entry.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  final CalendarViewModel _viewModel = CalendarViewModel();

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              CMS.calendar['title']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            elevation: 0,
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: _viewModel.fetchMonthData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Month Navigator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _viewModel.changeMonth(-1),
                      ),
                      Text(
                        DateFormat.yMMMM().format(_viewModel.focusedDate),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _viewModel.changeMonth(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. HeatMap Block
                  // 2. HeatMap Block
                  if (_viewModel.isLoading)
                    const ShimmerLoading(width: double.infinity, height: 320)
                  else
                    FadeInEntry(
                      child: GestureDetector(
                        onHorizontalDragEnd: (details) {
                          if (details.primaryVelocity! < 0) {
                            // Swipe Left -> Next Month
                            _viewModel.changeMonth(1);
                          } else if (details.primaryVelocity! > 0) {
                            // Swipe Right -> Prev Month
                            _viewModel.changeMonth(-1);
                          }
                        },
                        child: HeatMapBlock(
                          focusedDate: _viewModel.focusedDate,
                          dailyNet: _viewModel.dailyNet,
                          maxNet: _viewModel.maxNet,
                          rangeStart: _viewModel.rangeStart,
                          rangeEnd: _viewModel.rangeEnd,
                          onDaySelected: (date) {
                            _viewModel.onDaySelected(date);
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 3. Filter & Sort Options (Moved below Heatmap)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.filter_list, size: 16),
                          label: Text("Filter"),
                          onPressed: _showFilterOptions,
                          backgroundColor:
                              _viewModel.selectedCategoryIds.isNotEmpty ||
                                      _viewModel.selectedSenders.isNotEmpty
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer
                                  : null,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.sort, size: 16),
                          label: Text(_getSortLabel()),
                          onPressed: _showSortOptions,
                        ),
                        if (_viewModel.selectedCategoryIds.isNotEmpty ||
                            _viewModel.selectedSenders.isNotEmpty ||
                            _viewModel.rangeStart != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              _viewModel.resetFilters();
                            },
                            child: Text("Reset"), // Renamed from Reset Filters
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Day/Range Summary
                  if (_viewModel.rangeStart != null) ...[
                    DaySummaryBlock(
                      selectedDate: _viewModel.rangeStart!,
                      endDate: _viewModel.rangeEnd,
                      transactions: _viewModel.getTransactionsInRange(),
                    ),
                    const SizedBox(height: 16),

                    // Transaction List for the Day
                    _buildTransactionList(_viewModel.getTransactionsInRange()),
                  ] else ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        "Select a day to view transactions",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> txs) {
    if (txs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            CMS.calendar['no_transactions_month']!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: txs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = txs[index];
        final isCredit = tx['type'] == 'credit';
        final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
        final formattedDate = DateFormat('MMM d, h:mm a').format(date);

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    isCredit
                        ? AppColors.incomeBackground
                        : AppColors.expenseBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                size: 18,
                color: isCredit ? AppColors.income : AppColors.expense,
              ),
            ),
            title: Text(
              tx['patternName'] ?? tx['sender'] ?? "Unknown",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx['categoryName'] ?? 'Uncategorized'),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            trailing: Text(
              "${tx['amount']}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
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
              if (context.mounted) {
                _viewModel.fetchMonthData();
              }
            },
          ),
        );
      },
    );
  }
}
