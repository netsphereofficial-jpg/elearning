import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/course_model.dart';
import '../services/course_service.dart';
import '../services/google_auth_service.dart';
import 'payment_screen.dart';
import 'video_player_screen.dart';
import '../models/video_model.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final CourseService _courseService = CourseService();
  bool _isEnrolled = false;
  bool _isCheckingEnrollment = true;

  @override
  void initState() {
    super.initState();
    _checkEnrollment();
  }

  Future<void> _checkEnrollment() async {
    setState(() => _isCheckingEnrollment = true);

    try {
      final authService = context.read<GoogleAuthService>();
      final userId = authService.currentUser?.uid;

      if (userId != null) {
        final enrolled = await _courseService.isUserEnrolled(userId, widget.course.id);
        setState(() {
          _isEnrolled = enrolled;
          _isCheckingEnrollment = false;
        });
      } else {
        setState(() => _isCheckingEnrollment = false);
      }
    } catch (e) {
      setState(() => _isCheckingEnrollment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking enrollment: $e')),
        );
      }
    }
  }

  void _navigateToPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(course: widget.course),
      ),
    ).then((_) {
      // Refresh enrollment status when returning from payment
      _checkEnrollment();
    });
  }

  void _playVideo(CourseVideo video) {
    // Convert CourseVideo to VideoModel for compatibility with existing player
    final videoModel = VideoModel(
      id: video.videoId,
      title: video.title,
      description: video.description,
      bunnyVideoGuid: video.bunnyVideoGuid,
      thumbnailUrl: video.thumbnailUrl,
      durationInSeconds: video.durationInSeconds,
      category: widget.course.title,
      uploadedAt: widget.course.createdAt,
      tags: [],
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(video: videoModel),
      ),
    );
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Content Locked'),
        content: const Text('Please enroll in this course to access all videos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToPayment();
            },
            child: const Text('Enroll Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Details'),
      ),
      body: _isCheckingEnrollment
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Course header with thumbnail
                  _buildCourseHeader(),

                  // Course info
                  _buildCourseInfo(),

                  // Course content (videos list)
                  _buildCourseContent(),

                  // Enroll button (if not enrolled)
                  if (!_isEnrolled) _buildEnrollButton(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCourseHeader() {
    return CachedNetworkImage(
      imageUrl: widget.course.thumbnailUrl,
      height: 250,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        height: 250,
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        height: 250,
        color: Colors.grey[300],
        child: const Icon(Icons.school, size: 80, color: Colors.white),
      ),
    );
  }

  Widget _buildCourseInfo() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course title
          Text(
            widget.course.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          // Course description
          Text(
            widget.course.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 16),

          // Course stats
          Row(
            children: [
              // Price
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹${widget.course.price}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Video count
              Icon(Icons.play_circle_outline, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${widget.course.totalVideos} videos',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(width: 16),

              // Duration
              Icon(Icons.access_time, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                widget.course.formattedTotalDuration,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),

          // Enrollment status
          if (_isEnrolled)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You are enrolled in this course',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course Content',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Videos list
          ...widget.course.videos.map((video) => _buildVideoListItem(video)),
        ],
      ),
    );
  }

  Widget _buildVideoListItem(CourseVideo video) {
    final isLocked = !video.isFree && !_isEnrolled;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[300],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const Icon(Icons.play_circle_outline),
            ),
          ),
        ),
        title: Row(
          children: [
            if (video.isFree)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'FREE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                '${video.order}. ${video.title}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        subtitle: Text(
          video.formattedDuration,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: isLocked
            ? const Icon(Icons.lock, color: Colors.grey)
            : Icon(Icons.play_circle_filled, color: Theme.of(context).colorScheme.primary),
        onTap: () {
          if (isLocked) {
            _showLockedDialog();
          } else {
            _playVideo(video);
          }
        },
      ),
    );
  }

  Widget _buildEnrollButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: _navigateToPayment,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Enroll Now - ₹${widget.course.price}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
