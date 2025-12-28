import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class TicketModal extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const TicketModal({super.key, required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Allow scrolling if content is long
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: ShapeDecoration(
              color: backgroundColor ?? Theme.of(context).cardColor,
              shape: _ReceiptShapeBorder(),
              shadows: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipPath(
              clipper: _ReceiptClipper(),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptShapeBorder extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path();
    const toothWidth = 20.0;
    const toothHeight = 10.0;

    path.moveTo(rect.left, rect.top);

    // Top Zigzag
    /*
    for (double i = rect.left; i < rect.right; i += toothWidth) {
       path.lineTo(i + toothWidth / 2, rect.top + toothHeight);
       path.lineTo(i + toothWidth, rect.top);
    }
    */
    // Straight top
    path.lineTo(rect.right, rect.top);

    path.lineTo(rect.right, rect.bottom - toothHeight);

    // Bottom Zigzag
    for (double i = rect.right; i > rect.left; i -= toothWidth) {
      path.lineTo(i - toothWidth / 2, rect.bottom);
      path.lineTo(i - toothWidth, rect.bottom - toothHeight);
    }

    path.lineTo(rect.left, rect.top);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

class _ReceiptClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const toothWidth = 20.0;
    const toothHeight = 10.0;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - toothHeight);

    for (double i = size.width; i > 0; i -= toothWidth) {
      path.lineTo(i - toothWidth / 2, size.height);
      path.lineTo(i - toothWidth, size.height - toothHeight);
    }

    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
