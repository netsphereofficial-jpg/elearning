import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:async';
import 'dart:html' as html;
import '../models/course_model.dart';
import '../services/google_auth_service.dart';
import '../services/course_progress_service.dart';
import '../services/bunny_stream_service.dart';
import '../constants/app_theme.dart';

class CourseVideoPlayerScreen extends StatefulWidget {
  final CourseVideo video;
  final String courseId;
  final String courseTitle;
  final int videoDuration;

  const CourseVideoPlayerScreen({
    super.key,
    required this.video,
    required this.courseId,
    required this.courseTitle,
    required this.videoDuration,
  });

  @override
  State<CourseVideoPlayerScreen> createState() => _CourseVideoPlayerScreenState();
}

class _CourseVideoPlayerScreenState extends State<CourseVideoPlayerScreen> {
  final CourseProgressService _progressService = CourseProgressService();
  final BunnyStreamService _bunnyService = BunnyStreamService();

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  int _maxWatchedPosition = 0;
  int _currentPosition = 0;
  bool _isCompleted = false;
  Timer? _progressTimer;
  int _totalWatchTime = 0;
  DateTime? _sessionStartTime;
  bool _isSeekRestrictionActive = false;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _initializePlayer();
    _disableRightClickOnVideo();
  }

  // Disable right-click context menu on video elements (web only)
  void _disableRightClickOnVideo() {
    // Try multiple times to catch video elements as they load
    for (int i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: 500 * (i + 1)), () {
        try {
          // Find all video elements in the page
          final videos = html.document.querySelectorAll('video');
          print('Found ${videos.length} video elements');

          for (var video in videos) {
            // Disable context menu (right-click)
            video.addEventListener('contextmenu', (event) {
              event.preventDefault();
              event.stopPropagation();
              return false;
            });

            // Disable download attribute
            video.setAttribute('controlsList', 'nodownload noremoteplayback');

            // Disable picture-in-picture
            video.setAttribute('disablePictureInPicture', 'true');

            // Disable right-click on video controls
            video.setAttribute('oncontextmenu', 'return false;');

            print('✅ Disabled right-click on video element');
          }

          // Also disable right-click on the entire video container
          final videoContainers = html.document.querySelectorAll('.video-wrapper, video-container');
          for (var container in videoContainers) {
            container.addEventListener('contextmenu', (event) {
              event.preventDefault();
              event.stopPropagation();
              return false;
            });
          }
        } catch (e) {
          print('❌ Error disabling right-click: $e');
        }
      });
    }
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

      // Load existing watch session to get max watched position
      final session = await _progressService.getVideoWatchSession(
        user.uid,
        widget.video.videoId,
      );

      if (session != null) {
        _maxWatchedPosition = session.maxWatchedPosition;
        _currentPosition = session.lastWatchedPosition;
        _isCompleted = session.isCompleted;
        _totalWatchTime = session.totalWatchTime;
      }

      // Get Bunny Stream playback URL
      final videoGuid = widget.video.bunnyVideoGuid;

      print('🎬 Loading Bunny Stream video: $videoGuid');

      // Get HLS playlist URL for adaptive streaming
      // Bunny Stream handles all security, DRM, and download protection automatically
      final videoUrl = _bunnyService.getPlaybackUrl(videoGuid);

      print('✅ Using Bunny Stream HLS URL: $videoUrl');
      print('🔒 Bunny Stream provides: Adaptive bitrate, DRM, Download protection');

      // Initialize video player with Bunny Stream HLS URL
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      await _videoPlayerController!.initialize();

      // Create Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
          handleColor: AppTheme.primaryColor,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
      );

      // Add listener for position tracking and seek restrictions
      _videoPlayerController!.addListener(_onVideoPositionChanged);

      // Start from last watched position (but only if not completed)
      // For completed videos, user can watch from anywhere they prefer
      if (!_isCompleted && _currentPosition > 0 && _currentPosition < widget.videoDuration) {
        await _videoPlayerController!.seekTo(Duration(seconds: _currentPosition));
      }

      // Start progress tracking timer
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

  void _onVideoPositionChanged() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }

    final position = _videoPlayerController!.value.position;
    final positionSeconds = position.inSeconds;

    _currentPosition = positionSeconds;

    // Update max watched position if user progressed forward (only for first-time viewing)
    if (!_isCompleted && positionSeconds > _maxWatchedPosition) {
      _maxWatchedPosition = positionSeconds;
    }

    // SEEK RESTRICTION: Prevent fast-forward ONLY on first-time viewing (not completed)
    // If video was previously completed, user can skip/fast-forward freely
    if (!_isCompleted && !_isSeekRestrictionActive && positionSeconds > _maxWatchedPosition + 2) {
      _isSeekRestrictionActive = true;
      print('⚠️ Seeking ahead blocked! Rewinding to max position: $_maxWatchedPosition');
      _videoPlayerController!.seekTo(Duration(seconds: _maxWatchedPosition)).then((_) {
        _isSeekRestrictionActive = false;
      });
      _showSeekBlockedMessage();
    }

    // Check for completion (95% watched) - only mark if not already completed
    if (!_isCompleted && positionSeconds >= widget.videoDuration * 0.95) {
      _markVideoCompleted();
    }
  }

  void _showSeekBlockedMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please watch the video completely first before skipping ahead'),
              ),
            ],
          ),
          backgroundColor: AppTheme.warningColor,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _startProgressTracking(String userId) {
    // Save progress every 5 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
        final sessionDuration = DateTime.now().difference(_sessionStartTime!).inSeconds;

        await _progressService.updateVideoProgress(
          userId: userId,
          videoId: widget.video.videoId,
          currentPosition: _currentPosition,
          maxWatchedPosition: _maxWatchedPosition,
          totalWatchTime: _totalWatchTime + sessionDuration,
          deviceId: 'web_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    });
  }

  Future<void> _markVideoCompleted() async {
    if (_isCompleted) return;

    setState(() {
      _isCompleted = true;
    });

    try {
      final authService = context.read<GoogleAuthService>();
      final user = authService.currentUser;

      if (user != null) {
        await _progressService.markVideoCompleted(
          userId: user.uid,
          courseId: widget.courseId,
          videoId: widget.video.videoId,
          videoDuration: widget.videoDuration,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${widget.video.title} completed! ✓'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error marking video completed: $e');
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoPlayerController?.removeListener(_onVideoPositionChanged);
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              widget.video.title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Completed',
                    style: TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorWidget()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Video player (16:9 aspect ratio)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: MouseRegion(
                          onEnter: (_) => _disableRightClickOnVideo(),
                          child: GestureDetector(
                            onSecondaryTap: () {
                              // Block right-click tap
                              print('🚫 Right-click blocked');
                            },
                            onSecondaryTapDown: (_) {
                              // Block right-click down
                              print('🚫 Right-click blocked');
                            },
                            onLongPress: () {
                              // Block long press (mobile)
                              print('🚫 Long press blocked');
                            },
                            child: Listener(
                              onPointerDown: (event) {
                                // Prevent right-click context menu (download/save options)
                                if (event.buttons == 2) {
                                  print('🚫 Right mouse button blocked');
                                  // Right mouse button - do nothing to prevent context menu
                                  return;
                                }
                              },
                              child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                                  ? Chewie(controller: _chewieController!)
                                  : Container(
                                      color: Colors.black,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Seek restriction warning banner (only for first-time viewing)
                      if (!_isCompleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.2),
                            border: Border(
                              bottom: BorderSide(color: AppTheme.warningColor, width: 2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'First-time watch: Skipping ahead is disabled until you complete the video',
                                  style: TextStyle(
                                    color: AppTheme.warningColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Info banner for completed videos (re-watching)
                      if (_isCompleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.2),
                            border: Border(
                              bottom: BorderSide(color: AppTheme.successColor, width: 2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You\'ve completed this video. You can now skip and fast-forward freely!',
                                  style: TextStyle(
                                    color: AppTheme.successColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
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
                              // Progress bar
                              if (!_isCompleted) ...[
                                LinearProgressIndicator(
                                  value: widget.videoDuration > 0 ? _maxWatchedPosition / widget.videoDuration : 0,
                                  backgroundColor: Colors.grey[800],
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Progress: ${widget.videoDuration > 0 ? (_maxWatchedPosition / widget.videoDuration * 100).toStringAsFixed(0) : 0}% watched',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Video title
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${widget.video.order}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.video.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Video metadata
                              Row(
                                children: [
                                  Icon(Icons.access_time, color: Colors.grey[400], size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.video.formattedDuration,
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                  if (widget.video.isFree) ...[
                                    const SizedBox(width: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'FREE PREVIEW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Video description
                            Text(
                              widget.video.description,
                              style: TextStyle(color: Colors.grey[300], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
