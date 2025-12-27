import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/cms.dart';

class TransactionContainer extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const TransactionContainer({super.key, required this.transactions});

  String getMonthName(int monthNumber) {
    if (monthNumber < 1 || monthNumber > 12) {
      return CMS.errors['invalid_month']!;
    }
    return CMS.months[monthNumber - 1];
  }

  String getFormatedDate(String date) {
    final dateDate = DateTime.parse(date);
    return "${dateDate.day} ${getMonthName(dateDate.month)} ${dateDate.year}";
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        final isDebit = transaction["type"] == "DEBITED";
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
          elevation: 0,
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(
                  Icons.monetization_on,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24.0,
                ),
              ),
            ),
            title: Text("${transaction["entity"]}"),
            subtitle: Text(getFormatedDate(transaction["date"])),
            trailing: Text(
              "₹${transaction["cost"]}",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDebit ? AppColors.expense : AppColors.income,
              ),
            ),
          ),
        );
      },
    );
  }
}
