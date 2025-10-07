import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class WatermarkOverlay extends StatefulWidget {
  final String userEmail;
  final String videoId;

  const WatermarkOverlay({
    super.key,
    required this.userEmail,
    required this.videoId,
  });

  @override
  State<WatermarkOverlay> createState() => _WatermarkOverlayState();
}

class _WatermarkOverlayState extends State<WatermarkOverlay> {
  Timer? _timer;
  Alignment _alignment = Alignment.topRight;
  double _opacity = 0.5;

  final List<Alignment> _positions = [
    Alignment.topRight,
    Alignment.topLeft,
    Alignment.bottomRight,
    Alignment.bottomLeft,
    Alignment.center,
  ];

  int _currentPositionIndex = 0;

  @override
  void initState() {
    super.initState();
    // Move watermark position every 15 seconds to prevent easy cropping
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      setState(() {
        _currentPositionIndex = (_currentPositionIndex + 1) % _positions.length;
        _alignment = _positions[_currentPositionIndex];
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 800),
        alignment: _alignment,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Opacity(
            opacity: _opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userEmail,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    'ID: ${widget.videoId.substring(0, 8)}...',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
