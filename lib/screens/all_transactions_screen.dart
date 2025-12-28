import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  final String? title;
  final List<Map<String, dynamic>> transactions;

  const AllTransactionsScreen({
    super.key,
    required this.transactions,
    this.title,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late List<Map<String, dynamic>> _transactions;

  @override
  void initState() {
    super.initState();
    // Create a mutable copy of the list
    _transactions = List.from(widget.transactions);
  }

  @override
  Widget build(BuildContext context) {
    if (_transactions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? "All Transactions")),
        body: Center(
          child: Text(
            "No transactions yet",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Group transactions by Date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var tx in _transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
      final key = _getDateKey(date);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }

    final keys = grouped.keys.toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? "All Transactions")),
      body: ListView.builder(
        itemCount: keys.length,
        itemBuilder: (context, sectionIndex) {
          final key = keys[sectionIndex];
          final txs = grouped[key]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // Transactions in this group
              ...txs.map((tx) {
                final type = (tx['type'] as String?)?.toUpperCase() ?? '';
                final isDebit = type.contains('DEBIT');
                final amount = (tx['amount'] as num).toDouble();
                final date = DateTime.fromMillisecondsSinceEpoch(tx['date']);
                final sender = tx['sender'] ?? 'Unknown';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isDebit
                            ? AppColors.expense.withValues(alpha: 0.1)
                            : AppColors.income.withValues(alpha: 0.1),
                    child: Icon(
                      isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isDebit ? AppColors.expense : AppColors.income,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    sender,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat('h:mm a').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    "${isDebit ? '-' : '+'}₹${amount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDebit ? AppColors.expense : AppColors.income,
                    ),
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                TransactionDetailScreen(transaction: tx),
                      ),
                    );

                    if (result != null && result is Map) {
                      final action = result['action'];
                      if (action == 'delete') {
                        setState(() {
                          _transactions.removeWhere(
                            (t) => t['id'] == result['id'],
                          );
                        });
                      } else if (action == 'update') {
                        final updatedTx = result['transaction'];
                        setState(() {
                          final index = _transactions.indexWhere(
                            (t) => t['id'] == updatedTx['id'],
                          );
                          if (index != -1) {
                            _transactions[index] = updatedTx;
                            // Re-sort if date changed?
                            // Assuming list was sorted by date desc
                            _transactions.sort(
                              (a, b) => (b['date'] as int).compareTo(
                                a['date'] as int,
                              ),
                            );
                          }
                        });
                      }
                    }
                  },
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (checkDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, y').format(date);
    }
  }
}
