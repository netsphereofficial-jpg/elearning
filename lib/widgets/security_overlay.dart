import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window, document;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class SecurityOverlay extends StatefulWidget {
  const SecurityOverlay({super.key});

  @override
  State<SecurityOverlay> createState() => _SecurityOverlayState();
}

class _SecurityOverlayState extends State<SecurityOverlay> {
  bool _devToolsDetected = false;
  Timer? _devToolsCheckTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupSecurityMeasures();
      _startDevToolsDetection();
    }
  }

  void _setupSecurityMeasures() {
    try {
      // Disable right-click context menu
      html.document.onContextMenu.listen((event) {
        event.preventDefault();
      });

      // Disable common keyboard shortcuts for saving/downloading
      html.document.onKeyDown.listen((event) {
        // Ctrl+S (Save)
        if (event.ctrlKey && event.key == 's') {
          event.preventDefault();
        }
        // Ctrl+Shift+S (Save As)
        if (event.ctrlKey && event.shiftKey && event.key == 's') {
          event.preventDefault();
        }
        // F12 (DevTools)
        if (event.key == 'F12') {
          event.preventDefault();
        }
        // Ctrl+Shift+I (Inspect)
        if (event.ctrlKey && event.shiftKey && event.key == 'i') {
          event.preventDefault();
        }
        // Ctrl+Shift+J (Console)
        if (event.ctrlKey && event.shiftKey && event.key == 'j') {
          event.preventDefault();
        }
        // Ctrl+U (View Source)
        if (event.ctrlKey && event.key == 'u') {
          event.preventDefault();
        }
      });

      // Prevent text selection on video overlay using JS interop
      js.context.callMethod('eval', [
        "document.body.style.userSelect = 'none';"
            "document.body.style.webkitUserSelect = 'none';"
            "document.body.style.mozUserSelect = 'none';"
            "document.body.style.msUserSelect = 'none';"
      ]);
    } catch (e) {
      // Silently fail if web APIs aren't available
      debugPrint('Security setup error: $e');
    }
  }

  void _startDevToolsDetection() {
    // Simple DevTools detection
    // Note: This is easily bypassable but adds a layer of deterrence
    _devToolsCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        const threshold = 160;
        // Window dimensions - using ! to handle nullable types
        // ignore: unnecessary_non_null_assertion
        final widthDiff = html.window.outerWidth! - html.window.innerWidth!;
        // ignore: unnecessary_non_null_assertion
        final heightDiff = html.window.outerHeight! - html.window.innerHeight!;

        final widthThreshold = widthDiff > threshold;
        final heightThreshold = heightDiff > threshold;

        if (widthThreshold || heightThreshold) {
          if (!_devToolsDetected) {
            setState(() {
              _devToolsDetected = true;
            });
          }
        } else {
          if (_devToolsDetected) {
            setState(() {
              _devToolsDetected = false;
            });
          }
        }
      } catch (e) {
        // Silently fail if detection doesn't work
        debugPrint('DevTools detection error: $e');
      }
    });
  }

  @override
  void dispose() {
    _devToolsCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_devToolsDetected) {
      return const SizedBox.shrink();
    }

    // Show warning overlay when DevTools detected
    return Container(
      color: Colors.black87,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 80,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Developer Tools Detected',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please close developer tools to continue watching.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Video playback is paused for security reasons.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _devToolsDetected = false;
                    });
                  },
                  child: const Text('I\'ve Closed DevTools'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
