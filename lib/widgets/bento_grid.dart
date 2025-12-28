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
    // For a true "Bento" feel with spanning, we usually need StaggeredGrid.
    // However, without external deps, we'll implement a simple uniform grid
    // for 1x1 items, and expect the caller to use specific "BentoRow" widgets
    // for more complex layouts (2x1, etc).
    // This widget serves as a clean wrapper for uniform grids (like Categories).

    return GridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class BentoRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  final double spacing;

  const BentoRow({
    super.key,
    required this.children,
    this.flex,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(children.length, (index) {
        final flexFactor =
            flex != null && index < flex!.length ? flex![index] : 1;
        final isLast = index == children.length - 1;

        return Expanded(
          flex: flexFactor,
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : spacing),
            child: children[index],
          ),
        );
      }),
    );
  }
}
