import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class HeatMapBlock extends StatelessWidget {
  final DateTime focusedDate;
  final Map<int, double> dailyNet;
  final double maxNet;
  final DateTime? selectedDate;
  final Function(DateTime) onDaySelected;

  const HeatMapBlock({
    super.key,
    required this.focusedDate,
    required this.dailyNet,
    required this.maxNet,
    this.selectedDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(focusedDate.year, focusedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(focusedDate.year, focusedDate.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday % 7;

    return Column(
      children: [
        // Weekday Headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              ["S", "M", "T", "W", "T", "F", "S"]
                  .map(
                    (d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 12),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysInMonth + weekdayOffset,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            if (index < weekdayOffset) {
              return const SizedBox.shrink();
            }

            final day = index - weekdayOffset + 1;
            final date = DateTime(focusedDate.year, focusedDate.month, day);

            final isSelected =
                selectedDate != null &&
                date.year == selectedDate!.year &&
                date.month == selectedDate!.month &&
                date.day == selectedDate!.day;

            final isToday = _isSameDay(date, DateTime.now());

            return _buildDayCell(context, day, date, isSelected, isToday);
          },
        ),
      ],
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    int day,
    DateTime date,
    bool isSelected,
    bool isToday,
  ) {
    Color? bgColor;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    if (dailyNet.containsKey(day)) {
      final net = dailyNet[day]!;
      double intensity = (net.abs() / (maxNet == 0 ? 1 : maxNet)).clamp(
        0.2,
        1.0,
      );

      if (net < 0) {
        // Expense -> Red/Coral
        bgColor = AppColors.expense.withValues(alpha: intensity);
        // If intensity is high, use white text
        if (intensity > 0.5) textColor = Colors.white;
      } else if (net > 0) {
        // Income -> Green/Emerald
        bgColor = AppColors.income.withValues(alpha: intensity);
        if (intensity > 0.5) textColor = Colors.black;
      }
    } else {
      // Empty day
      bgColor = Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    }

    if (isSelected) {
      // Highlight selected
      bgColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimary;
    }

    return GestureDetector(
      onTap: () => onDaySelected(date),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border:
              isToday
                  ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                  : null,
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        alignment: Alignment.center,
        child: Text(
          "$day",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
