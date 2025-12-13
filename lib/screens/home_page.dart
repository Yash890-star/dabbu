import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:dabbu/services/message_helper.dart';
import 'package:dabbu/services/database_helper.dart';
import 'package:dabbu/widgets/transaction_container.dart';
import 'package:dabbu/screens/new_account.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {

  List<Map<String, dynamic>> transactions = [];
  final dbHelper = DatabaseHelper.instance;

  Future<void> _getAllTransaction() async {
    await MessageHelper.getNewTransactions();
    final db = await dbHelper.database;
    List<Map<String, dynamic>> dbTransactions = await db.query(
        MessageHelper.transactionTable,
        orderBy: 'date DESC'
    );
    log("Homepage::_getAllTransactions $dbTransactions");
    setState(() {
      transactions = dbTransactions;
    });
  }

  @override
  void initState() {
    super.initState();
    MessageHelper.initTelephony();
    _getAllTransaction();
  }

  Widget _renderEmptyMessageText() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Text("Please add messages to continue"),
        ]
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dabbu"),
      ),
      body: RefreshIndicator(
        onRefresh: _getAllTransaction,
        child: transactions.isEmpty
            ? _renderEmptyMessageText()
            : TransactionContainer(transactions: transactions),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          log("Action button pressed");
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewAccount()),
          );
        },
        label: Text("New message"),
        icon: Icon(Icons.add),
      ),
    );
  }
}
