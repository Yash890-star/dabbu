import 'package:flutter/material.dart';

class SenderFilterBlock extends StatelessWidget {
  final List<String> availableSenders;
  final List<String> selectedSenders;
  final Function(String) onSenderTap;

  const SenderFilterBlock({
    super.key,
    required this.availableSenders,
    required this.selectedSenders,
    required this.onSenderTap,
  });

  @override
  Widget build(BuildContext context) {
    if (availableSenders.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableSenders.length,
        separatorBuilder: (c, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sender = availableSenders[index];
          final isSelected = selectedSenders.contains(sender);

          return ActionChip(
            label: Text(sender),
            onPressed: () => onSenderTap(sender),
            backgroundColor:
                isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
            side:
                BorderSide
                    .none, // Bento style usually cleaner without chip border if using AppCard style, but standard Chip is fine for filters
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
