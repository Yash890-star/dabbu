import 'package:flutter/material.dart';

class SmsCodeBlock extends StatelessWidget {
  final List<String> tokens;
  final Function(int) onTokenTap;
  final int? selectedAmountIndex;
  final int? prefixStart;
  final int? prefixEnd;
  final int? suffixStart;
  final int? suffixEnd;

  const SmsCodeBlock({
    super.key,
    required this.tokens,
    required this.onTokenTap,
    this.selectedAmountIndex,
    this.prefixStart,
    this.prefixEnd,
    this.suffixStart,
    this.suffixEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark terminal background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 8,
        children: List.generate(tokens.length, (index) {
          Color bgColor = Colors.transparent;
          Color textColor = Colors.white70;
          FontWeight fontWeight = FontWeight.normal;

          bool isSelected = false;

          // HIGHTLIGHT LOGIC
          if (index == selectedAmountIndex) {
            bgColor = Colors.greenAccent.shade700;
            textColor = Colors.white;
            fontWeight = FontWeight.bold;
            isSelected = true;
          } else if (prefixStart != null &&
              prefixEnd != null &&
              index >= prefixStart! &&
              index <= prefixEnd!) {
            bgColor = Colors.blueAccent;
            textColor = Colors.white;
            fontWeight = FontWeight.bold;
            isSelected = true;
          } else if (suffixStart != null &&
              suffixEnd != null &&
              index >= suffixStart! &&
              index <= suffixEnd!) {
            bgColor = Colors.blueAccent;
            textColor = Colors.white;
            fontWeight = FontWeight.bold;
            isSelected = true;
          } else if (prefixEnd != null &&
              selectedAmountIndex != null &&
              index > prefixEnd! &&
              index < selectedAmountIndex!) {
            // Gap between prefix and amount
            textColor = Colors.white30;
          } else if (suffixStart != null &&
              selectedAmountIndex != null &&
              index > selectedAmountIndex! &&
              index < suffixStart!) {
            // Gap between amount and suffix
            textColor = Colors.white30;
          }

          return InkWell(
            onTap: () => onTokenTap(index),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(4),
                border: isSelected ? null : Border.all(color: Colors.white10),
              ),
              child: Text(
                tokens[index],
                style: TextStyle(
                  color: textColor,
                  fontWeight: fontWeight,
                  fontFamily: 'RobotoMono', // Monospace
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
