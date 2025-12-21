import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_helper.dart';
import '../services/message_helper.dart'; // Import the new helper
import 'transaction_detail_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = "";
  List<Map<String, dynamic>> _transactions = [];
  bool _isSyncing = false; // To show loading spinner

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    // Fetch transactions joined with Categories
    final data = await DatabaseHelper.instance.getTransactionsWithDetails();

    setState(() {
      _userName = prefs.getString('userName') ?? "User";
      _transactions = data;
    });
  }

  // --- THE NEW SYNC FUNCTION ---
  Future<void> _syncMessages() async {
    setState(() => _isSyncing = true);

    final helper = MessageHelper();

    // We scan the last 60 days by default to catch old messages for new patterns
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hello, $_userName"),
        actions: [
          // Manual Sync Button
          IconButton(
            icon:
                _isSyncing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : _syncMessages,
          ),
        ],
      ),
      body: RefreshIndicator(
        // Pull to refresh support
        onRefresh: _syncMessages,
        child:
            _transactions.isEmpty
                ? ListView(
                  // ListView is needed for RefreshIndicator to work even if empty
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
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            tx['type'] == 'credit'
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                        child: Icon(
                          tx['type'] == 'credit'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color:
                              tx['type'] == 'credit'
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                      title: Text(tx['sender']),
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
                        // Navigate to Detail Screen
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    TransactionDetailScreen(transaction: tx),
                          ),
                        );
                        // Refresh list when coming back (in case category changed)
                        _loadData();
                      },
                    );
                  },
                ),
      ),
    );
  }
}
