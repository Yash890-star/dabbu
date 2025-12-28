import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

import '../app_card.dart';

class HeatMapBlock extends StatelessWidget {
  final DateTime focusedDate;
  final Map<int, double> dailyNet;
  final double maxNet;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final Function(DateTime) onDaySelected;

  const HeatMapBlock({
    super.key,
    required this.focusedDate,
    required this.dailyNet,
    required this.maxNet,
    this.rangeStart,
    this.rangeEnd,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(focusedDate.year, focusedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(focusedDate.year, focusedDate.month, 1);
    final weekdayOffset = firstDayOfMonth.weekday % 7;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
            itemCount: 42, // Force 6 weeks * 7 days to keep height constant
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index < weekdayOffset ||
                  index >= daysInMonth + weekdayOffset) {
                return const SizedBox.shrink();
              }

              final day = index - weekdayOffset + 1;
              final date = DateTime(focusedDate.year, focusedDate.month, day);

              // Range Logic
              bool isStart =
                  rangeStart != null && _isSameDay(date, rangeStart!);
              bool isEnd = rangeEnd != null && _isSameDay(date, rangeEnd!);
              bool isInRange =
                  rangeStart != null &&
                  rangeEnd != null &&
                  date.isAfter(rangeStart!) &&
                  date.isBefore(rangeEnd!) &&
                  true;

              bool isSelected = isStart || isEnd || isInRange;
              final isToday = _isSameDay(date, DateTime.now());

              return _buildDayCell(
                context,
                day,
                date,
                isSelected,
                isStart,
                isEnd,
                isInRange,
                isToday,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    int day,
    DateTime date,
    bool isSelected,
    bool isStart,
    bool isEnd,
    bool isInRange,
    bool isToday,
  ) {
    Color? bgColor;
    Color textColor = Theme.of(context).colorScheme.onSurface;
    BoxBorder? border;

    // Base Heatmap Color
    if (dailyNet.containsKey(day)) {
      final net = dailyNet[day]!;
      // Boost min intensity to 0.3 for better visibility on dark backgrounds
      double intensity = (net.abs() / (maxNet == 0 ? 1 : maxNet)).clamp(
        0.3,
        1.0,
      );

      if (net > 0) {
        // Expense -> Red/Coral
        bgColor = AppColors.expense.withValues(alpha: intensity);
        if (intensity > 0.5) textColor = Colors.white;
      } else if (net < 0) {
        // Income -> Green/Emerald
        bgColor = AppColors.income.withValues(alpha: intensity);
        if (intensity > 0.5) textColor = Colors.black;
      }
    } else {
      // Empty day
      // Use a subtle fill that contrasts with the Card background
      bgColor = Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.15);
    }

    // Selection Logic: High Contrast Outline ONLY (No Overlay, No Shadow)
    if (isSelected) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      // Apply border to ALL selected dates (Start, End, and Range)
      border = Border.all(
        color: isDark ? Colors.white : Colors.black,
        width: 2.5,
      );
    }

    // Today Indicator (Secondary priority)
    if (isToday && border == null) {
      border = Border.all(
        color: Theme.of(context).colorScheme.primary,
        width: 2,
      );
    }

    return GestureDetector(
      onTap: () => onDaySelected(date),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: border,
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
