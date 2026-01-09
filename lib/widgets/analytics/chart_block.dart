import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_card.dart';

class ChartBlock extends StatefulWidget {
  final List<ChartSectionData> sections;
  final double totalAmount;
  final String centerLabel;
  final bool isEmpty;

  const ChartBlock({
    super.key,
    required this.sections,
    required this.totalAmount,
    this.centerLabel = "Total",
    this.isEmpty = false,
  });

  @override
  State<ChartBlock> createState() => _ChartBlockState();
}

class _ChartBlockState extends State<ChartBlock> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.isEmpty) {
      return AppCard(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48,
                color: Theme.of(context).disabledColor,
              ),
              const SizedBox(height: 8),
              Text(
                "No Data",
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height:
                200, // Reduced height for chart area to avoid overflow if list is added
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            if (event is FlTapUpEvent) {
                              _touchedIndex = -1;
                            }
                            return;
                          }

                          if (event is FlTapUpEvent) {
                            _touchedIndex =
                                pieTouchResponse
                                    .touchedSection!
                                    .touchedSectionIndex;
                          }
                        });
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: _buildSections(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.centerLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NumberFormat.compactCurrency(
                        symbol: '₹',
                      ).format(widget.totalAmount),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Keep the list view but use widget.sections
          ListView.separated(
            shrinkWrap: true,
            itemCount: widget.sections.length > 3 ? 3 : widget.sections.length,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final section = widget.sections[index];
              return Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: section.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    NumberFormat.compactCurrency(
                      symbol: '₹',
                      decimalDigits: 0,
                    ).format(section.value),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    return widget.sections.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final isTouched = index == _touchedIndex;
      final fontSize =
          isTouched
              ? 16.0
              : 0.0; // Hide title by default, show on touch? Or just radius
      final radius = isTouched ? 30.0 : 20.0;

      return PieChartSectionData(
        color: data.color,
        value: data.value,
        title: '${data.percentage.toStringAsFixed(0)}%',
        radius: radius,
        showTitle: isTouched, // Only show title when touched
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}

class ChartSectionData {
  final Color color;
  final double value;
  final double percentage;
  final String title;

  ChartSectionData({
    required this.color,
    required this.value,
    required this.percentage,
    required this.title,
  });
}
