import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class GlowGauge extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double startAngle;
  final double durationSeconds;

  const GlowGauge({
    super.key,
    required this.progress,
    this.startAngle = -220, // Typical gauge start
    this.durationSeconds = 1.0,
  });

  @override
  State<GlowGauge> createState() => _GlowGaugeState();
}

class _GlowGaugeState extends State<GlowGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.durationSeconds * 1000).toInt()),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.progress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _controller.forward();
  }

  @override
  void didUpdateWidget(GlowGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _GlowGaugePainter(
            progress: _animation.value,
            primaryColor: AppColors.primary,
            secondaryColor: AppColors.primary.withValues(alpha: 0.1),
          ),
          child: Container(),
        );
      },
    );
  }
}

class _GlowGaugePainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _GlowGaugePainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 5;
    const strokeWidth = 14.0;

    // Background Arc
    final bgPaint =
        Paint()
          ..color = secondaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    // 240 degrees arc (from 150 to 390)
    // -225 degrees = 135 degrees? No, let's use standard radians.
    // Start at 135 degrees (Bottom Leftish) and go 270 degrees.
    // Let's use 3/4 circle. Start -225deg, sweep 270deg.

    // Using -220 degrees start as requested in widget default, so let's stick to standard gauge.
    // Start: 135 degrees (3pi/4). Sweep: 270 degrees (3pi/2).
    const startAngle = 135 * pi / 180;
    const sweepAngle = 270 * pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Foreground Gradient Arc
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [primaryColor.withValues(alpha: 0.5), primaryColor],
      tileMode: TileMode.repeated,
    );

    final fgPaint =
        Paint()
          ..shader = gradient.createShader(
            Rect.fromCircle(center: center, radius: radius),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    // Glow Effect (Shadow behind the arc)
    final glowPaint =
        Paint()
          ..color = primaryColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final currentSweep = sweepAngle * progress;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        currentSweep,
        false,
        glowPaint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        currentSweep,
        false,
        fgPaint,
      );
    }

    // Draw Knob at the end
    if (progress > 0) {
      final endAngle = startAngle + currentSweep;
      final knobX = center.dx + radius * cos(endAngle);
      final knobY = center.dy + radius * sin(endAngle);

      final knobPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(knobX, knobY), strokeWidth / 2 - 2, knobPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
