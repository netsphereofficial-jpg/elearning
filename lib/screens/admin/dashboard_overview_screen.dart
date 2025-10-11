import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../services/admin_course_service.dart';
import '../../services/admin_payment_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_enrollment_service.dart';

class DashboardOverviewScreen extends StatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  State<DashboardOverviewScreen> createState() => _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState extends State<DashboardOverviewScreen> {
  final AdminCourseService _courseService = AdminCourseService();
  final AdminPaymentService _paymentService = AdminPaymentService();
  final AdminUserService _userService = AdminUserService();
  final AdminEnrollmentService _enrollmentService = AdminEnrollmentService();

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final courseStats = await _courseService.getCourseStats();
      final paymentStats = await _paymentService.getPaymentStats();
      final userStats = await _userService.getUserStats();
      final enrollmentStats = await _enrollmentService.getEnrollmentStats();

      if (mounted) {
        setState(() {
          _stats = {
            ...courseStats,
            ...paymentStats,
            ...userStats,
            ...enrollmentStats,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard Overview', style: AppTheme.headlineMD),
            const SizedBox(height: AppTheme.spacingLG),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _buildStatsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.getGridColumns(context).clamp(1, 4);
        final cardWidth = (constraints.maxWidth - (AppTheme.spacingMD * (columns - 1))) / columns;

        return Wrap(
          spacing: AppTheme.spacingMD,
          runSpacing: AppTheme.spacingMD,
          children: [
            _buildStatCard(
              'Total Users',
              '${_stats['total'] ?? 0}',
              Icons.people,
              AppTheme.primaryColor,
              width: cardWidth,
            ),
            _buildStatCard(
              'Total Courses',
              '${_stats['published'] ?? 0}/${_stats['total'] ?? 0}',
              Icons.school,
              AppTheme.secondaryColor,
              width: cardWidth,
            ),
            _buildStatCard(
              'Pending Payments',
              '${_stats['pending'] ?? 0}',
              Icons.pending_actions,
              AppTheme.warningColor,
              width: cardWidth,
            ),
            _buildStatCard(
              'Total Revenue',
              '₹${_stats['totalRevenue'] ?? 0}',
              Icons.currency_rupee,
              AppTheme.successColor,
              width: cardWidth,
            ),
            _buildStatCard(
              'Live Students',
              '${_stats['liveStudents'] ?? 0}',
              Icons.check_circle,
              const Color(0xFF10B981), // Green
              width: cardWidth,
            ),
            _buildStatCard(
              'Expired Students',
              '${_stats['expiredStudents'] ?? 0}',
              Icons.cancel,
              const Color(0xFFEF4444), // Red
              width: cardWidth,
            ),
            _buildStatCard(
              'Expiring Soon',
              '${_stats['expiringSoon'] ?? 0}',
              Icons.warning,
              const Color(0xFFF59E0B), // Orange
              width: cardWidth,
            ),
            _buildStatCard(
              'Total Enrollments',
              '${_stats['totalEnrollments'] ?? 0}',
              Icons.assignment,
              const Color(0xFF8B5CF6), // Purple
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {required double width}) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                value,
                style: AppTheme.headlineLG.copyWith(color: color),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                title,
                style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
