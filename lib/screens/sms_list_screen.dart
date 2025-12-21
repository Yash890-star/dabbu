import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:intl/intl.dart';

// The big complex screen comes next
import 'sms_parsing_screen.dart';

class SmsListScreen extends StatelessWidget {
  final List<SmsMessage> messages;

  const SmsListScreen({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Transaction")),
      body:
          messages.isEmpty
              ? const Center(child: Text("No messages found."))
              : ListView.separated(
                itemCount: messages.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final msg = messages[index];

                  final date =
                      msg.date != null
                          ? DateFormat('MMM d, h:mm a').format(
                            DateTime.fromMillisecondsSinceEpoch(msg.date!),
                          )
                          : 'Unknown Date';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.message, color: Colors.blue),
                    ),
                    title: Text(
                      msg.address ?? "Unknown Sender",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          msg.body ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SmsParsingScreen(message: msg),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
