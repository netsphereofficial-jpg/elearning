import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/video_model.dart';
import '../services/auth_service.dart';
import '../services/video_service.dart';
import '../widgets/watermark_overlay.dart';
import '../widgets/security_overlay.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  final VideoService _videoService = VideoService();

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _userEmail;

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
      final authService = context.read<AuthService>();
      final user = authService.currentUser;

      if (user == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get user email for watermark
      _userEmail = user.email;

      // Check if user has access to this video
      final hasAccess = await _videoService.checkVideoAccess(
        user.uid,
        widget.video.id,
      );

      if (!hasAccess) {
        setState(() {
          _hasError = true;
          _errorMessage = 'You don\'t have access to this video';
          _isLoading = false;
        });
        return;
      }

      // Get signed video URL
      final signedUrl = await _videoService.generateSignedVideoUrl(
        user.uid,
        widget.video.id,
      );

      if (signedUrl == null) {
        // For demo purposes, use a placeholder URL
        // In production, this would be the Cloudflare Stream signed URL
        setState(() {
          _hasError = true;
          _errorMessage = 'Could not generate video URL. Please configure Cloud Functions.';
          _isLoading = false;
        });
        return;
      }

      // Get previous watch session
      final watchSession = await _videoService.getWatchSession(
        user.uid,
        widget.video.id,
      );

      // Initialize video player
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(signedUrl),
      );

      await _videoPlayerController!.initialize();

      // Resume from last position if available
      if (watchSession != null && watchSession.lastWatchedPosition > 0) {
        await _videoPlayerController!.seekTo(
          Duration(seconds: watchSession.lastWatchedPosition),
        );
      }

      // Initialize Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey[300]!,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text(
                  'Error: $errorMessage',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
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
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_videoPlayerController != null && _videoPlayerController!.value.isPlaying) {
        final currentPosition = _videoPlayerController!.value.position.inSeconds;
        _totalWatchTime += 10;

        // Save progress every 10 seconds
        if ((currentPosition - _lastSavedPosition).abs() > 5) {
          await _videoService.updateWatchProgress(
            userId: userId,
            videoId: widget.video.id,
            currentPosition: currentPosition,
            totalWatchTime: _totalWatchTime,
            deviceId: 'web_${DateTime.now().millisecondsSinceEpoch}',
          );
          _lastSavedPosition = currentPosition;
        }

        // Mark as completed if watched 90% or more
        final duration = _videoPlayerController!.value.duration.inSeconds;
        if (currentPosition >= duration * 0.9) {
          await _videoService.markVideoCompleted(userId, widget.video.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
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
                    // Video player with security
                    Expanded(
                      child: Stack(
                        children: [
                          // Video player
                          Center(
                            child: _chewieController != null
                                ? Chewie(controller: _chewieController!)
                                : const CircularProgressIndicator(),
                          ),

                          // Watermark overlay
                          if (_userEmail != null)
                            WatermarkOverlay(
                              userEmail: _userEmail!,
                              videoId: widget.video.id,
                            ),

                          // Security overlay (prevents screenshots, detects DevTools)
                          const SecurityOverlay(),
                        ],
                      ),
                    ),

                    // Video info
                    Container(
                      color: Colors.grey[900],
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
