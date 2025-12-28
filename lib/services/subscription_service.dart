import 'database_helper.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  /// Scans the last [days] of transactions to find recurring patterns.
  Future<List<Map<String, dynamic>>> scanForSubscriptions({
    int days = 90,
  }) async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days)).millisecondsSinceEpoch;

    // 1. Fetch transactions (Debit/Expense only)
    final allTxs =
        await db.getTransactionsWithDetails(); // This returns everything
    final recentTxs =
        allTxs.where((tx) {
          if (tx['date'] < cutoff) return false;
          final type = tx['type'];
          return type == 'debit' || type == 'expense';
        }).toList();

    // 2. Group by Sender
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var tx in recentTxs) {
      final sender = (tx['sender'] as String?)?.trim() ?? "Unknown";
      if (sender == "Unknown") continue;

      grouped.putIfAbsent(sender, () => []).add(tx);
    }

    final List<Map<String, dynamic>> candidates = [];

    // 3. Analyze patterns
    for (var entry in grouped.entries) {
      final sender = entry.key;
      final txs = entry.value;

      // Need at least 2 to form a pattern
      if (txs.length < 2) continue;

      // Sort by date ASC
      txs.sort((a, b) => (a['date'] as int).compareTo(b['date'] as int));

      // Check Amounts: Are they similar?
      // simple check: if variance is low
      final amounts = txs.map((t) => (t['amount'] as num).toDouble()).toList();
      double sum = amounts.reduce((a, b) => a + b);
      double avgAmount = sum / amounts.length;

      bool consistentAmount = true;
      for (var amt in amounts) {
        if ((amt - avgAmount).abs() > (avgAmount * 0.2)) {
          // 20% tolerance
          consistentAmount = false;
          break;
        }
      }

      // Check Intervals: Are they monthly-ish?
      // 25 to 35 days
      bool monthlyPattern = true;
      if (txs.length >= 2) {
        for (int i = 0; i < txs.length - 1; i++) {
          final d1 = DateTime.fromMillisecondsSinceEpoch(txs[i]['date']);
          final d2 = DateTime.fromMillisecondsSinceEpoch(txs[i + 1]['date']);
          final diff = d2.difference(d1).inDays;

          // Allow 25-35 days for monthly
          // Or 28-31 strictly?
          // Some bills might be erratic manually paid.
          // Let's broaden to 20-40 to catch "roughly monthly"
          if (diff < 20 || diff > 40) {
            monthlyPattern = false;
            break;
          }
        }
      }

      if (consistentAmount && monthlyPattern) {
        // Estimate next bill
        final lastDate = DateTime.fromMillisecondsSinceEpoch(txs.last['date']);
        final nextDate = lastDate.add(const Duration(days: 30));

        candidates.add({
          'name': sender,
          'sender': sender,
          'amount': avgAmount,
          'period': 30, // Assumed monthly
          'nextBillDate': nextDate.millisecondsSinceEpoch,
          'avgAmount': avgAmount,
          'txCount': txs.length,
          'lastDate': lastDate.millisecondsSinceEpoch,
        });
      }
    }

    return candidates;
  }
}
