import 'package:flutter/material.dart';

class FadeInEntry extends StatefulWidget {
  final Widget child;
  final int delay; // milliseconds
  final Duration duration;
  final Offset offset;

  const FadeInEntry({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0.0, 0.1), // Slight slide up
  });

  @override
  State<FadeInEntry> createState() => _FadeInEntryState();
}

class _FadeInEntryState extends State<FadeInEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _fade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _slide = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.delay == 0) {
      _controller.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
