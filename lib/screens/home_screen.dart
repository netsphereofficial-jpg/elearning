import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_theme.dart';
import '../models/course_model.dart';
import '../services/course_service.dart';
import 'course_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToCourses;

  const HomeScreen({
    super.key,
    required this.onNavigateToCourses,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CourseService _courseService = CourseService();
  List<CourseModel> _featuredCourses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeaturedCourses();
  }

  Future<void> _loadFeaturedCourses() async {
    try {
      final courses = await _courseService.getAllCourses();
      if (mounted) {
        setState(() {
          _featuredCourses = courses.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeroSection(),
          _buildFeaturesSection(),
          _buildFeaturedCoursesSection(),
          _buildStatsSection(),
          _buildCTASection(),
          const SizedBox(height: AppTheme.spacingXXL),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
          vertical: isMobile ? AppTheme.spacingXXL : AppTheme.spacingXXL * 3,
        ),
        child: Column(
          children: [
            Text(
              'Learn Without Limits',
              textAlign: TextAlign.center,
              style: (isMobile ? AppTheme.headlineLG : AppTheme.headlineXL).copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'Master new skills with expert-led courses. Learn at your own pace, from anywhere.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyLG.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontSize: isMobile ? 16 : 20,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HeroButton(
                  label: 'Explore Courses',
                  onPressed: widget.onNavigateToCourses,
                  isPrimary: true,
                ),
                const SizedBox(width: AppTheme.spacingMD),
                _HeroButton(
                  label: 'Learn More',
                  onPressed: () {},
                  isPrimary: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final isMobile = Breakpoints.isMobile(context);
    final features = [
      _Feature(
        icon: Icons.school,
        title: 'Expert Instructors',
        description: 'Learn from industry professionals with years of experience',
      ),
      _Feature(
        icon: Icons.play_circle_outline,
        title: 'Video Lessons',
        description: 'High-quality video content you can watch anytime, anywhere',
      ),
      _Feature(
        icon: Icons.workspace_premium,
        title: 'Certificates',
        description: 'Earn certificates upon completion to showcase your skills',
      ),
      _Feature(
        icon: Icons.support_agent,
        title: '24/7 Support',
        description: 'Get help whenever you need it from our support team',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL * 2,
      ),
      child: Column(
        children: [
          Text(
            'Why Choose Us',
            style: isMobile ? AppTheme.headlineMD : AppTheme.headlineLG,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            'Everything you need to succeed in your learning journey',
            style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXL),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = Breakpoints.getGridColumns(context);
              return Wrap(
                spacing: AppTheme.spacingLG,
                runSpacing: AppTheme.spacingLG,
                children: features.map((feature) {
                  return SizedBox(
                    width: (constraints.maxWidth - (AppTheme.spacingLG * (columns - 1))) / columns,
                    child: _FeatureCard(feature: feature),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCoursesSection() {
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      color: AppTheme.backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL * 2,
      ),
      child: Column(
        children: [
          Text(
            'Featured Courses',
            style: isMobile ? AppTheme.headlineMD : AppTheme.headlineLG,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            'Start learning with our most popular courses',
            style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXL),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _featuredCourses.isEmpty
                  ? const Text('No courses available')
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = Breakpoints.getGridColumns(context).clamp(1, 3);
                        return Wrap(
                          spacing: AppTheme.spacingLG,
                          runSpacing: AppTheme.spacingLG,
                          children: _featuredCourses.map((course) {
                            return SizedBox(
                              width: (constraints.maxWidth - (AppTheme.spacingLG * (columns - 1))) / columns,
                              child: _CourseCard(course: course),
                            );
                          }).toList(),
                        );
                      },
                    ),
          const SizedBox(height: AppTheme.spacingXL),
          ElevatedButton(
            onPressed: widget.onNavigateToCourses,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXL,
                vertical: AppTheme.spacingMD,
              ),
            ),
            child: const Text('View All Courses'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final isMobile = Breakpoints.isMobile(context);
    final stats = [
      _Stat(value: '10,000+', label: 'Students'),
      _Stat(value: '50+', label: 'Courses'),
      _Stat(value: '98%', label: 'Success Rate'),
      _Stat(value: '24/7', label: 'Support'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL * 2,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: AppTheme.spacingXL,
            runSpacing: AppTheme.spacingXL,
            alignment: WrapAlignment.center,
            children: stats.map((stat) {
              return _StatCard(stat: stat);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCTASection() {
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingLG : AppTheme.spacingXXL * 2,
        vertical: AppTheme.spacingXXL,
      ),
      padding: EdgeInsets.all(isMobile ? AppTheme.spacingXL : AppTheme.spacingXXL * 2),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Column(
        children: [
          Text(
            'Ready to Start Learning?',
            style: (isMobile ? AppTheme.headlineMD : AppTheme.headlineLG).copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            'Join thousands of students already learning with us',
            style: AppTheme.bodyLG.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingXL),
          ElevatedButton(
            onPressed: widget.onNavigateToCourses,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? AppTheme.spacingXL : AppTheme.spacingXXL,
                vertical: AppTheme.spacingMD,
              ),
            ),
            child: const Text(
              'Browse Courses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _HeroButton({
    required this.label,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? Colors.white : Colors.white.withOpacity(0.2),
        foregroundColor: isPrimary ? AppTheme.primaryColor : Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXL,
          vertical: AppTheme.spacingMD,
        ),
        elevation: isPrimary ? 4 : 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(feature.icon, color: Colors.white, size: 32),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              feature.title,
              style: AppTheme.titleMD,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              feature.description,
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseModel course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: course.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.school, size: 60),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: AppTheme.titleMD,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    course.description,
                    style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${course.totalVideos} videos',
                        style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                      ),
                      Text(
                        '₹${course.price}',
                        style: AppTheme.titleMD.copyWith(color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _Stat stat;

  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          stat.value,
          style: AppTheme.headlineLG.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        Text(
          stat.label,
          style: AppTheme.bodyLG.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String description;

  const _Feature({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _Stat {
  final String value;
  final String label;

  const _Stat({
    required this.value,
    required this.label,
  });
}
