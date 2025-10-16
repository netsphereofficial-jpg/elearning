import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/course_model.dart';
import '../../services/admin_course_service.dart';
import 'course_form_screen.dart';

class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({super.key});

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  final AdminCourseService _courseService = AdminCourseService();
  List<CourseModel> _courses = [];
  bool _isLoading = true;
  bool _showPublishedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final courses = await _courseService.getAllCourses(
        isPublished: _showPublishedOnly ? true : null,
      );
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _togglePublish(CourseModel course) async {
    final success = await _courseService.togglePublishStatus(
      course.id,
      !course.isPublished,
    );
    if (success) {
      _loadCourses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(course.isPublished ? 'Course unpublished' : 'Course published'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteCourse(CourseModel course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Are you sure you want to delete "${course.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final result = await _courseService.deleteCourse(course.id);
      if (mounted) {
        if (result['success'] == true) {
          _loadCourses();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Course deleted'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete course'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  void _navigateToForm({CourseModel? course}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseFormScreen(course: course),
      ),
    );
    if (result == true) {
      _loadCourses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_courses.isEmpty)
            const Expanded(child: Center(child: Text('No courses found')))
          else
            Expanded(
              child: isMobile ? _buildMobileList() : _buildDesktopTable(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Course'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Row(
        children: [
          Text('Courses (${_courses.length})', style: AppTheme.titleLG),
          const Spacer(),
          FilterChip(
            label: const Text('Published Only'),
            selected: _showPublishedOnly,
            onSelected: (value) {
              setState(() => _showPublishedOnly = value);
              _loadCourses();
            },
          ),
          const SizedBox(width: AppTheme.spacingMD),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Title')),
          DataColumn(label: Text('Price')),
          DataColumn(label: Text('Videos')),
          DataColumn(label: Text('Validity')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _courses.map((course) {
          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(
                    course.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text('₹${course.price}')),
              DataCell(Text('${course.totalVideos}')),
              DataCell(Text('${course.validityDays} days')),
              DataCell(
                Chip(
                  label: Text(course.isPublished ? 'Published' : 'Draft'),
                  backgroundColor: course.isPublished
                      ? AppTheme.successColor.withOpacity(0.1)
                      : Colors.grey[300],
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _navigateToForm(course: course),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: Icon(
                        course.isPublished ? Icons.unpublished : Icons.publish,
                        size: 20,
                      ),
                      onPressed: () => _togglePublish(course),
                      tooltip: course.isPublished ? 'Unpublish' : 'Publish',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                      onPressed: () => _deleteCourse(course),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          child: ListTile(
            title: Text(course.title),
            subtitle: Text('₹${course.price} • ${course.totalVideos} videos • ${course.validityDays}d validity'),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'publish',
                  child: Text(course.isPublished ? 'Unpublish' : 'Publish'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _navigateToForm(course: course);
                    break;
                  case 'publish':
                    _togglePublish(course);
                    break;
                  case 'delete':
                    _deleteCourse(course);
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }
}
