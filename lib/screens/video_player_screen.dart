import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import '../models/video_model.dart';
import '../services/google_auth_service.dart';
import '../services/video_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final VideoService _videoService = VideoService();

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String _iframeViewType = '';

  Timer? _progressTimer;
  int _totalWatchTime = 0;
  int _lastSavedPosition = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final authService = context.read<GoogleAuthService>();
      final user = authService.currentUser;

      if (user == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Bunny Stream iframe URL
      final bunnyVideoGuid = widget.video.bunnyVideoGuid;
      final iframeUrl =
          'https://iframe.mediadelivery.net/play/506127/$bunnyVideoGuid';

      // Create unique view type for this video
      _iframeViewType = 'bunny-player-$bunnyVideoGuid';

      // Register the iframe view
      ui_web.platformViewRegistry.registerViewFactory(
        _iframeViewType,
        (int viewId) {
          final iframe = html.IFrameElement()
            ..src = iframeUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..setAttribute('allowfullscreen', 'true')
            ..setAttribute('allow', 'autoplay; encrypted-media; picture-in-picture');

          return iframe;
        },
      );

      // Start progress tracking
      _startProgressTracking(user.uid);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error initializing player: $e';
        _isLoading = false;
      });
    }
  }

  void _startProgressTracking(String userId) {
    // Simplified progress tracking for iframe player
    // In a full implementation, you'd use postMessage to communicate with the iframe
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      _totalWatchTime += 30;

      // Save progress every 30 seconds
      await _videoService.updateWatchProgress(
        userId: userId,
        videoId: widget.video.id,
        currentPosition: _totalWatchTime,
        totalWatchTime: _totalWatchTime,
        deviceId: 'web_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Mark as completed after watching for 90% of video duration
      if (_totalWatchTime >= widget.video.durationInSeconds * 0.9) {
        await _videoService.markVideoCompleted(userId, widget.video.id);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.video.title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorWidget()
              : Column(
                  children: [
                    // Video player (60% height)
                    Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.6,
                      color: Colors.black,
                      child: HtmlElementView(
                        viewType: _iframeViewType,
                      ),
                    ),

                    // Video info (40% height - scrollable)
                    Expanded(
                      child: Container(
                        color: Colors.grey[900],
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.video.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.visibility, color: Colors.grey[400], size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.video.viewCount} views',
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.access_time, color: Colors.grey[400], size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.video.formattedDuration,
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.video.description,
                                style: TextStyle(color: Colors.grey[300]),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: widget.video.tags.map((tag) {
                                  return Chip(
                                    label: Text(tag),
                                    backgroundColor: Colors.grey[800],
                                    labelStyle: const TextStyle(color: Colors.white),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 80),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
