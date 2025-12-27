import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:intl/intl.dart';
import '../viewmodels/sms_list_view_model.dart';

import 'sms_parsing_screen.dart';

class SmsListScreen extends StatefulWidget {
  final List<SmsMessage> messages;

  const SmsListScreen({super.key, required this.messages});

  @override
  State<SmsListScreen> createState() => _SmsListScreenState();
}

class _SmsListScreenState extends State<SmsListScreen> {
  final SmsListViewModel _viewModel = SmsListViewModel();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel.init(widget.messages);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
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
                            _viewModel.filterMessages("");
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
              onChanged: _viewModel.filterMessages,
            ),
          ),

          // List of filtered messages
          Expanded(
            child: AnimatedBuilder(
              animation: _viewModel,
              builder: (context, child) {
                if (_viewModel.filteredMessages.isEmpty) {
                  return Center(
                    child: Text(
                      widget.messages.isEmpty
                          ? "No messages found."
                          : "No matching results.",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: _viewModel.filteredMessages.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final msg = _viewModel.filteredMessages[index];

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
                            builder:
                                (context) => SmsParsingScreen(message: msg),
                          ),
                        );
                      },
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
