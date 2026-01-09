import 'package:flutter/material.dart';

class BentoGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const BentoGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 16.0,
    this.crossAxisSpacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox();

    // Manual Masonry Implementation
    // Distribute children into columns
    List<List<Widget>> columns = List.generate(crossAxisCount, (_) => []);

    for (int i = 0; i < children.length; i++) {
      columns[i % crossAxisCount].add(children[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          List.generate(crossAxisCount, (colIndex) {
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: List.generate(columns[colIndex].length, (
                      rowIndex,
                    ) {
                      final isLast = rowIndex == columns[colIndex].length - 1;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: isLast ? 0 : mainAxisSpacing,
                        ),
                        child: columns[colIndex][rowIndex],
                      );
                    }),
                  ),
                );
              })
              .expand(
                (widget) => [
                  widget,
                  if (children.length > 1) SizedBox(width: crossAxisSpacing),
                ],
              )
              .toList()
            ..removeLast(), // Add spacing between columns and remove the last one
    );
  }
}
