import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/cms.dart';
import '../viewmodels/subscriptions_view_model.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final SubscriptionsViewModel _viewModel = SubscriptionsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.loadSubscriptions();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _scanForSubscriptions() async {
    final candidates = await _viewModel.scanForSubscriptions();

    if (!mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CMS.subscriptions['no_patterns_found']!)),
      );
    } else {
      _showCandidatesDialog(candidates);
    }
  }

  void _showCandidatesDialog(List<Map<String, dynamic>> candidates) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(CMS.subscriptions['detected_title']!),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: candidates.length,
                itemBuilder: (context, index) {
                  final cand = candidates[index];
                  return ListTile(
                    title: Text(cand['name']),
                    subtitle: Text(
                      (CMS.subscriptions['avg_per_month'] as String)
                          .replaceFirst(
                            '{amount}',
                            cand['amount'].toStringAsFixed(0),
                          ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () async {
                        await _viewModel.createSubscription({
                          'name': cand['name'],
                          'amount': cand['amount'],
                          'sender': cand['sender'],
                          'period': 30,
                          'frequencyType': 'MONTH',
                          'frequencyValue': 1,
                          'nextBillDate': cand['nextBillDate'],
                          'isActive': 1,
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(CMS.subscriptions['close']!),
              ),
            ],
          ),
    );
  }

  String _getFrequencyLabel(String? type, int? val) {
    if (type == null) return "Monthly";
    final v = val ?? 1;
    if (v == 1) {
      switch (type) {
        case 'DAY':
          return "Daily";
        case 'WEEK':
          return "Weekly";
        case 'MONTH':
          return "Monthly";
        case 'YEAR':
          return "Yearly";
        default:
          return "Monthly";
      }
    } else {
      switch (type) {
        case 'DAY':
          return "Every $v Days";
        case 'WEEK':
          return "Every $v Weeks";
        case 'MONTH':
          return "Every $v Months";
        case 'YEAR':
          return "Every $v Years";
        default:
          return "Every $v Months";
      }
    }
  }

  void _showAddDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final frequencyValueController = TextEditingController(text: '1');

    String frequencyType = 'MONTH'; // Default
    DateTime selectedDate = DateTime.now();

    // Helper to update preview date based on frequency
    DateTime calculateNextDate(DateTime start, String type, int val) {
      switch (type) {
        case 'DAY':
          return start.add(Duration(days: val));
        case 'WEEK':
          return start.add(Duration(days: val * 7));
        case 'MONTH':
          return DateTime(start.year, start.month + val, start.day);
        case 'YEAR':
          return DateTime(start.year + val, start.month, start.day);
        default:
          return start.add(const Duration(days: 30));
      }
    }

    // Set initial target date
    selectedDate = calculateNextDate(DateTime.now(), frequencyType, 1);

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setState) {
              void updateDate() {
                final val = int.tryParse(frequencyValueController.text) ?? 1;
                // reset logic: projected from NOW or from a picked date?
                // Let's say user picks a "Start Date" or "Next Bill Date" manually
                // But for simplicity, let's keep the manual picker and just use frequency for future logic
                // For the dialog, we just need to collect inputs.
              }

              return AlertDialog(
                title: Text(CMS.subscriptions['add_title']!),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: CMS.subscriptions['name_label']!,
                        ),
                      ),
                      TextField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: CMS.subscriptions['amount_label']!,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Repeats Every:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: frequencyValueController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<String>(
                              value: frequencyType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'DAY',
                                  child: Text("Days"),
                                ),
                                DropdownMenuItem(
                                  value: 'WEEK',
                                  child: Text("Weeks"),
                                ),
                                DropdownMenuItem(
                                  value: 'MONTH',
                                  child: Text("Months"),
                                ),
                                DropdownMenuItem(
                                  value: 'YEAR',
                                  child: Text("Years"),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => frequencyType = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(CMS.subscriptions['next_bill_label']!),
                          TextButton(
                            child: Text(
                              DateFormat.yMMMd().format(selectedDate),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(CMS.common['cancel']!),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountController.text) ?? 0;
                      final freqVal =
                          int.tryParse(frequencyValueController.text) ?? 1;

                      if (nameController.text.isNotEmpty && amount > 0) {
                        await _viewModel.createSubscription({
                          'name': nameController.text,
                          'amount': amount,
                          'sender': nameController.text,
                          'period': 30, // Fallback/Legacy
                          'frequencyType': frequencyType,
                          'frequencyValue': freqVal,
                          'nextBillDate': selectedDate.millisecondsSinceEpoch,
                          'isActive': 1,
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      }
                    },
                    child: Text(CMS.subscriptions['add_btn']!),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(CMS.subscriptions['title']!),
        actions: [
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: CMS.subscriptions['scan_tooltip']!,
            onPressed: () => _scanForSubscriptions(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          if (_viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_viewModel.subscriptions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.subscriptions_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    CMS.subscriptions['no_subscriptions']!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () => _scanForSubscriptions(),
                    child: Text(CMS.subscriptions['scan_history_btn']!),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _viewModel.subscriptions.length,
            itemBuilder: (context, index) {
              final sub = _viewModel.subscriptions[index];
              final nextDate = DateTime.fromMillisecondsSinceEpoch(
                sub['nextBillDate'],
              );
              final daysLeft = nextDate.difference(DateTime.now()).inDays;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade50,
                    child: const Icon(Icons.receipt_long, color: Colors.purple),
                  ),
                  title: Text(
                    sub['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${CMS.subscriptions['next_due_label']!}${DateFormat.yMMMd().format(nextDate)} ($daysLeft${CMS.subscriptions['days_left_suffix']!})",
                      ),
                      Text(
                        _getFrequencyLabel(
                          sub['frequencyType'],
                          sub['frequencyValue'],
                        ),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "₹${sub['amount']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        onPressed:
                            () => _viewModel.deleteSubscription(sub['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
