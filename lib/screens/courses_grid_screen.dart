import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_theme.dart';
import '../models/course_model.dart';
import '../services/course_service.dart';
import 'course_detail_screen.dart';

class CoursesGridScreen extends StatefulWidget {
  const CoursesGridScreen({super.key});

  @override
  State<CoursesGridScreen> createState() => _CoursesGridScreenState();
}

class _CoursesGridScreenState extends State<CoursesGridScreen> {
  final CourseService _courseService = CourseService();
  List<CourseModel> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);

    try {
      final courses = await _courseService.getAllCourses();
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading courses: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(isMobile),
          _isLoading
              ? Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXXL),
                  child: const Center(child: CircularProgressIndicator()),
                )
              : _courses.isEmpty
                  ? _buildEmptyState()
                  : _buildCoursesGrid(),
          const SizedBox(height: AppTheme.spacingXXL),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: isMobile ? AppTheme.spacingXXL : AppTheme.spacingXXL * 2,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF9FAFB),
            Color(0xFFEBF4FF),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Our Courses',
            style: (isMobile ? AppTheme.headlineLG : AppTheme.headlineXL),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLG),
          Text(
            'Explore our comprehensive collection of courses',
            style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXXL * 2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No courses available',
              style: AppTheme.headlineSM,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'Check back later for new content',
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: _loadCourses,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesGrid() {
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingMD : AppTheme.spacingXL,
        vertical: AppTheme.spacingXL,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = Breakpoints.getGridColumns(context);
          return Wrap(
            spacing: AppTheme.spacingLG,
            runSpacing: AppTheme.spacingLG,
            children: _courses.map((course) {
              return SizedBox(
                width: (constraints.maxWidth - (AppTheme.spacingLG * (columns - 1))) / columns,
                child: _buildCourseCard(course),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCourseCard(CourseModel course) {
    return _CourseCard(course: course);
  }
}

class _CourseCard extends StatefulWidget {
  final CourseModel course;

  const _CourseCard({required this.course});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..translate(0.0, _isHovering ? -8.0 : 0.0),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: _isHovering ? 8 : 2,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseDetailScreen(course: widget.course),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thumbnail
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.course.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.school,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Price badge at top-right
                      Positioned(
                        top: AppTheme.spacingMD,
                        right: AppTheme.spacingMD,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMD,
                            vertical: AppTheme.spacingSM,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            boxShadow: [AppTheme.cardShadow],
                          ),
                          child: Text(
                            '₹${widget.course.price}',
                            style: AppTheme.bodyMD.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Hover overlay
                      if (_isHovering)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Course info
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.course.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.titleMD,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        widget.course.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.course.totalVideos} videos',
                            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(width: AppTheme.spacingMD),
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.course.formattedTotalDuration,
                            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
