import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/message_helper.dart';
import 'transaction_detail_screen.dart'; // Ensure this import exists

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = "";
  List<Map<String, dynamic>> _transactions = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = await DatabaseHelper.instance.getTransactionsWithDetails();

    if (mounted) {
      setState(() {
        _userName = prefs.getString('userName') ?? "User";
        _transactions = data;
      });
    }
  }

  Future<void> _syncMessages() async {
    setState(() => _isSyncing = true);
    final helper = MessageHelper();
    // Scan last 60 days
    int newCount = await helper.processNewMessages(lookBackDays: 60);
    await _loadData();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newCount > 0
                ? "Found $newCount new transactions!"
                : "No new transactions found.",
          ),
          backgroundColor: newCount > 0 ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- Date Helpers ---
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) return "Today";
    if (dateToCheck == yesterday) return "Yesterday";
    return DateFormat.yMMMd().format(date); // e.g., Dec 18, 2025
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hello, $_userName"),
        actions: [
          IconButton(
            icon:
                _isSyncing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : _syncMessages,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _syncMessages,
        child:
            _transactions.isEmpty
                ? ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Text(
                        "No transactions yet.\nPull down to scan.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
                : ListView.builder(
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      tx['date'],
                    );

                    // Logic to determine if we need a header
                    bool showHeader = false;
                    if (index == 0) {
                      showHeader = true; // First item always shows header
                    } else {
                      final prevTx = _transactions[index - 1];
                      final prevDate = DateTime.fromMillisecondsSinceEpoch(
                        prevTx['date'],
                      );
                      // If current date != previous date, show header
                      if (!_isSameDay(date, prevDate)) {
                        showHeader = true;
                      }
                    }

                    // Build the Transaction Tile
                    final tile = ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            tx['type'] == 'credit'
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                        child: Icon(
                          tx['type'] == 'credit'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color:
                              tx['type'] == 'credit'
                                  ? Colors.green
                                  : Colors.red,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        tx['sender'] ?? "Unknown",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(tx['categoryName'] ?? "Uncategorized"),
                      trailing: Text(
                        "${tx['amount']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              tx['type'] == 'credit'
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    TransactionDetailScreen(transaction: tx),
                          ),
                        );
                        _loadData(); // Refresh list on return
                      },
                    );

                    // Return Column if header is needed, otherwise just the tile
                    if (showHeader) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            child: Text(
                              _formatDateHeader(date),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          tile,
                        ],
                      );
                    } else {
                      return tile;
                    }
                  },
                ),
      ),
    );
  }
}
