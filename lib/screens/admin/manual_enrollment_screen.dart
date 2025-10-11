import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';
import '../../services/admin_enrollment_service.dart';
import '../../services/admin_course_service.dart';
import '../../services/admin_user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManualEnrollmentScreen extends StatefulWidget {
  const ManualEnrollmentScreen({super.key});

  @override
  State<ManualEnrollmentScreen> createState() => _ManualEnrollmentScreenState();
}

class _ManualEnrollmentScreenState extends State<ManualEnrollmentScreen> {
  final AdminEnrollmentService _enrollmentService = AdminEnrollmentService();
  final AdminCourseService _courseService = AdminCourseService();
  final AdminUserService _userService = AdminUserService();
  final TextEditingController _emailController = TextEditingController();

  UserModel? _selectedUser;
  List<CourseModel> _availableCourses = [];
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  Set<String> _selectedCourseIds = {};
  Set<String> _userEnrolledCourseIds = {};
  bool _isLoadingUser = false;
  bool _isLoadingCourses = true;
  bool _isEnrolling = false;
  bool _showUserSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadUsers();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    final query = _emailController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = [];
        _showUserSuggestions = false;
      });
    } else {
      setState(() {
        _filteredUsers = _allUsers.where((user) {
          return user.email.toLowerCase().contains(query) ||
              user.name.toLowerCase().contains(query);
        }).take(5).toList();
        _showUserSuggestions = _filteredUsers.isNotEmpty;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _userService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoadingCourses = true);
    try {
      final courses = await _courseService.getAllCourses(isPublished: true);
      if (mounted) {
        setState(() {
          _availableCourses = courses;
          _isLoadingCourses = false;
        });

        // Show info about loaded courses
        if (courses.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No published courses found. Please publish courses first.'),
              backgroundColor: AppTheme.warningColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoadingCourses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading courses: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _selectUser(UserModel user) async {
    setState(() {
      _isLoadingUser = true;
      _showUserSuggestions = false;
    });

    try {
      _emailController.text = user.email;
      // Get user's enrolled courses
      final enrolledCourseIds = await _enrollmentService.getUserEnrolledCourseIds(user.id);
      if (mounted) {
        setState(() {
          _selectedUser = user;
          _userEnrolledCourseIds = enrolledCourseIds.toSet();
          _selectedCourseIds.clear();
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingUser = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user enrollments: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _searchUser() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Try to find user from cached list first
    final user = _allUsers.where((u) => u.email.toLowerCase() == email).firstOrNull;
    if (user != null) {
      _selectUser(user);
      return;
    }

    // If not found in cache, try API
    setState(() => _isLoadingUser = true);
    try {
      final user = await _enrollmentService.getUserByEmail(email);
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found with this email'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        setState(() {
          _selectedUser = null;
          _userEnrolledCourseIds.clear();
          _selectedCourseIds.clear();
          _isLoadingUser = false;
        });
      } else {
        _selectUser(user);
      }
    } catch (e) {
      setState(() => _isLoadingUser = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching user: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _enrollUser() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select a user first'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one course'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Enrollment'),
        content: Text(
          'Enroll ${_selectedUser!.name} (${_selectedUser!.email}) in ${_selectedCourseIds.length} course(s)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text('Enroll'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isEnrolling = true);

    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Prepare course data
      final courseTitles = <String, String>{};
      final courseValidityDays = <String, int>{};

      for (final courseId in _selectedCourseIds) {
        final course = _availableCourses.firstWhere((c) => c.id == courseId);
        courseTitles[courseId] = course.title;
        courseValidityDays[courseId] = course.validityDays;
      }

      // Enroll in multiple courses
      final results = await _enrollmentService.manuallyEnrollUserInCourses(
        userId: _selectedUser!.id,
        userEmail: _selectedUser!.email,
        courseIds: _selectedCourseIds.toList(),
        courseTitles: courseTitles,
        courseValidityDays: courseValidityDays,
        adminId: adminId,
      );

      final successCount = results.values.where((success) => success).length;
      final failCount = results.values.where((success) => !success).length;

      setState(() => _isEnrolling = false);

      if (mounted) {
        String message;
        Color bgColor;

        if (failCount == 0) {
          message = 'Successfully enrolled in $successCount course(s)';
          bgColor = AppTheme.successColor;
        } else if (successCount == 0) {
          message = 'Failed to enroll in any courses';
          bgColor = AppTheme.errorColor;
        } else {
          message = 'Enrolled in $successCount course(s), $failCount failed';
          bgColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: bgColor,
          ),
        );

        // Reset form on success
        if (successCount > 0) {
          setState(() {
            _selectedCourseIds.clear();
            _emailController.clear();
            _selectedUser = null;
            _userEnrolledCourseIds.clear();
          });
        }
      }
    } catch (e) {
      setState(() => _isEnrolling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enrolling user: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Enrollment'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingCourses
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserSearchSection(isMobile),
                  if (_selectedUser != null) ...[
                    const SizedBox(height: AppTheme.spacingLG),
                    _buildUserInfoCard(),
                    const SizedBox(height: AppTheme.spacingLG),
                    _buildCourseSelectionSection(),
                    const SizedBox(height: AppTheme.spacingLG),
                    _buildEnrollButton(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildUserSearchSection(bool isMobile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search User', style: AppTheme.titleMD),
            const SizedBox(height: AppTheme.spacingMD),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'Type name or email to search...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _emailController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _emailController.clear();
                                    setState(() {
                                      _selectedUser = null;
                                      _userEnrolledCourseIds.clear();
                                      _selectedCourseIds.clear();
                                      _showUserSuggestions = false;
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoadingUser,
                        onSubmitted: (_) => _searchUser(),
                      ),
                      if (_showUserSuggestions && _filteredUsers.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundImage: user.photoUrl != null
                                      ? NetworkImage(user.photoUrl!)
                                      : null,
                                  child: user.photoUrl == null
                                      ? Text(user.name[0].toUpperCase())
                                      : null,
                                ),
                                title: Text(user.name, style: AppTheme.bodySM),
                                subtitle: Text(user.email, style: AppTheme.bodySM),
                                onTap: () => _selectUser(user),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                ElevatedButton.icon(
                  onPressed: _isLoadingUser ? null : _searchUser,
                  icon: _isLoadingUser
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingLG,
                      vertical: AppTheme.spacingMD,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      color: AppTheme.successColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _selectedUser!.photoUrl != null
                      ? NetworkImage(_selectedUser!.photoUrl!)
                      : null,
                  child: _selectedUser!.photoUrl == null
                      ? Text(
                          _selectedUser!.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 24),
                        )
                      : null,
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedUser!.name, style: AppTheme.titleMD),
                      Text(
                        _selectedUser!.email,
                        style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Wrap(
                        spacing: AppTheme.spacingSM,
                        children: [
                          Chip(
                            label: Text(
                              _selectedUser!.role.name.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (_selectedUser!.isPremium)
                            const Chip(
                              label: Text('PREMIUM', style: TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppTheme.accentColor,
                            ),
                          if (_selectedUser!.isBlocked)
                            const Chip(
                              label: Text('BLOCKED', style: TextStyle(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: AppTheme.errorColor,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_userEnrolledCourseIds.isNotEmpty) ...[
              const Divider(height: AppTheme.spacingLG),
              Text(
                'Currently enrolled in ${_userEnrolledCourseIds.length} course(s)',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSelectionSection() {
    final availableToEnroll = _availableCourses
        .where((course) => !_userEnrolledCourseIds.contains(course.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Select Courses', style: AppTheme.titleMD),
                const Spacer(),
                if (_selectedCourseIds.isNotEmpty)
                  Text(
                    '${_selectedCourseIds.length} selected',
                    style: AppTheme.bodySM.copyWith(color: AppTheme.primaryColor),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Total: ${_availableCourses.length} courses, Already enrolled: ${_userEnrolledCourseIds.length}, Available: ${availableToEnroll.length}',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            if (_availableCourses.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  children: [
                    const Icon(Icons.school_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'No published courses available.',
                      style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Please create and publish courses first in the Courses section.',
                      style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else if (availableToEnroll.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'User is already enrolled in all ${_availableCourses.length} published course(s)!',
                      style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...availableToEnroll.map((course) => _buildCourseCheckbox(course)),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCheckbox(CourseModel course) {
    final isSelected = _selectedCourseIds.contains(course.id);
    final isAlreadyEnrolled = _userEnrolledCourseIds.contains(course.id);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      color: isAlreadyEnrolled
          ? Colors.grey[200]
          : (isSelected ? AppTheme.primaryColor.withOpacity(0.1) : null),
      child: CheckboxListTile(
        value: isSelected,
        enabled: !isAlreadyEnrolled,
        onChanged: isAlreadyEnrolled
            ? null
            : (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedCourseIds.add(course.id);
                  } else {
                    _selectedCourseIds.remove(course.id);
                  }
                });
              },
        title: Text(course.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${course.totalVideos} videos • ${course.formattedTotalDuration} • Valid for ${course.validityDays} days',
              style: AppTheme.bodySM,
            ),
            if (isAlreadyEnrolled)
              Text(
                'Already enrolled',
                style: AppTheme.bodySM.copyWith(
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        secondary: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          child: Image.network(
            course.thumbnailUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.video_library),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrollButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isEnrolling || _selectedCourseIds.isEmpty ? null : _enrollUser,
        icon: _isEnrolling
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.person_add),
        label: Text(_isEnrolling ? 'Enrolling...' : 'Enroll User'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.successColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
          textStyle: AppTheme.titleMD,
        ),
      ),
    );
  }
}
