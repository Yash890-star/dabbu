import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:dabbu/services/message_helper.dart';

class NewAccount extends StatefulWidget {
  const NewAccount({super.key});

  @override
  State<NewAccount> createState() => _NewAccountState();
}

class _NewAccountState extends State<NewAccount> {

  List<SmsMessage> transactions = [];

  void submitHandler(String value) async {
    List<SmsMessage> messages = await MessageHelper.getFewMessagesFromCurrentBank(value);
    setState(() {
      transactions = messages;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add new messages"),
      ),
      body: Container(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(border: OutlineInputBorder(), labelText: "SMS Address"),
              onSubmitted: (String value) {
                log("value - $value");
                submitHandler(value);
              },
            ),
          )

        ],),
      ),
    ) ;
  }
}
