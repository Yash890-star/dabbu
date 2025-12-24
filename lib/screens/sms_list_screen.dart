import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:intl/intl.dart';

import 'sms_parsing_screen.dart';

class SmsListScreen extends StatefulWidget {
  final List<SmsMessage> messages;

  const SmsListScreen({super.key, required this.messages});

  @override
  State<SmsListScreen> createState() => _SmsListScreenState();
}

class _SmsListScreenState extends State<SmsListScreen> {
  late List<SmsMessage> _filteredMessages;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredMessages = widget.messages;
  }

  void _filterMessages(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredMessages = widget.messages;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredMessages =
          widget.messages.where((msg) {
            final address = (msg.address ?? "").toLowerCase();
            final body = (msg.body ?? "").toLowerCase();
            return address.contains(lowerQuery) || body.contains(lowerQuery);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Transaction")),
      body: Column(
        children: [
          // Persistent Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search sender or message...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterMessages("");
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _filterMessages,
            ),
          ),

          // List of filtered messages
          Expanded(
            child:
                _filteredMessages.isEmpty
                    ? Center(
                      child: Text(
                        widget.messages.isEmpty
                            ? "No messages found."
                            : "No matching results.",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                    : ListView.separated(
                      itemCount: _filteredMessages.length,
                      separatorBuilder:
                          (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final msg = _filteredMessages[index];

                        final date =
                            msg.date != null
                                ? DateFormat('MMM d, h:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                    msg.date!,
                                  ),
                                )
                                : 'Unknown Date';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: const Icon(
                              Icons.message,
                              color: Colors.blue,
                            ),
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
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SmsParsingScreen(message: msg),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
