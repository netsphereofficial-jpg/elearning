import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_theme.dart';
import '../../models/enrollment_model.dart';
import '../../services/admin_enrollment_service.dart';

class EnrollmentsListScreen extends StatefulWidget {
  const EnrollmentsListScreen({super.key});

  @override
  State<EnrollmentsListScreen> createState() => _EnrollmentsListScreenState();
}

class _EnrollmentsListScreenState extends State<EnrollmentsListScreen> {
  final AdminEnrollmentService _enrollmentService = AdminEnrollmentService();
  List<EnrollmentModel> _enrollments = [];
  List<EnrollmentModel> _filteredEnrollments = [];
  bool _isLoading = true;
  String _filterType = 'all'; // all, live, expired, expiring

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
  }

  Future<void> _loadEnrollments() async {
    setState(() => _isLoading = true);
    try {
      final enrollments = await _enrollmentService.getAllEnrollments(status: 'approved');
      setState(() {
        _enrollments = enrollments;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading enrollments: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_filterType == 'all') {
        _filteredEnrollments = _enrollments;
      } else if (_filterType == 'live') {
        _filteredEnrollments = _enrollments.where((e) => e.isValid).toList();
      } else if (_filterType == 'expired') {
        _filteredEnrollments = _enrollments.where((e) => !e.isValid).toList();
      } else if (_filterType == 'expiring') {
        _filteredEnrollments = _enrollments.where((e) => e.isValid && e.isExpiringSoon).toList();
      }
    });
  }

  Future<void> _showExtendValidityDialog(EnrollmentModel enrollment) async {
    final daysController = TextEditingController(text: '30');

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extend Validity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Course: ${enrollment.courseTitle}'),
            Text('User: ${enrollment.userEmail}'),
            const SizedBox(height: AppTheme.spacingMD),
            if (enrollment.validUntil != null)
              Text(
                'Current expiry: ${_formatDate(enrollment.validUntil!)}',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
              ),
            const SizedBox(height: AppTheme.spacingMD),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Extend by (days)',
                hintText: 'Enter number of days',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final days = int.tryParse(daysController.text);
              if (days != null && days > 0) {
                Navigator.pop(context, days);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number of days')),
                );
              }
            },
            child: const Text('Extend'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      final success = await _enrollmentService.extendEnrollmentValidity(enrollment.id, result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validity extended by $result days'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadEnrollments();
      }
    }
  }

  Future<void> _showUpdateValidityDialog(EnrollmentModel enrollment) async {
    DateTime selectedDate = enrollment.validUntil ?? DateTime.now().add(const Duration(days: 30));

    final result = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Validity Date'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Course: ${enrollment.courseTitle}'),
              Text('User: ${enrollment.userEmail}'),
              const SizedBox(height: AppTheme.spacingMD),
              if (enrollment.validUntil != null)
                Text(
                  'Current expiry: ${_formatDate(enrollment.validUntil!)}',
                  style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                ),
              const SizedBox(height: AppTheme.spacingMD),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = picked;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text('Selected: ${_formatDate(selectedDate)}'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedDate),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final success = await _enrollmentService.updateEnrollmentValidity(enrollment.id, result);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validity updated to ${_formatDate(result)}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadEnrollments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filteredEnrollments.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _filterType == 'all'
                      ? 'No enrollments found'
                      : 'No $_filterType enrollments found',
                ),
              ),
            )
          else
            Expanded(child: _buildEnrollmentsList()),
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Enrollments (${_filteredEnrollments.length})', style: AppTheme.titleLG),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadEnrollments,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _enrollments.length),
                const SizedBox(width: AppTheme.spacingSM),
                _buildFilterChip(
                  'Live',
                  'live',
                  _enrollments.where((e) => e.isValid).length,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                _buildFilterChip(
                  'Expired',
                  'expired',
                  _enrollments.where((e) => !e.isValid).length,
                  color: const Color(0xFFEF4444),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                _buildFilterChip(
                  'Expiring Soon',
                  'expiring',
                  _enrollments.where((e) => e.isValid && e.isExpiringSoon).length,
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count, {Color? color}) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
          _applyFilter();
        });
      },
      backgroundColor: color?.withOpacity(0.1) ?? Colors.grey[200],
      selectedColor: color ?? AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (color ?? Colors.black87),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildEnrollmentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _filteredEnrollments.length,
      itemBuilder: (context, index) {
        final enrollment = _filteredEnrollments[index];

        // Determine status
        Color statusColor;
        IconData statusIcon;
        String statusText;

        if (enrollment.isValid) {
          statusColor = const Color(0xFF10B981);
          statusIcon = Icons.check_circle;
          statusText = 'LIVE';
          if (enrollment.isExpiringSoon) {
            statusColor = const Color(0xFFF59E0B);
            statusIcon = Icons.warning;
            statusText = 'EXPIRING SOON';
          }
        } else {
          statusColor = const Color(0xFFEF4444);
          statusIcon = Icons.cancel;
          statusText = 'EXPIRED';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enrollment.courseTitle,
                            style: AppTheme.titleMD,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            enrollment.userEmail,
                            style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: AppTheme.bodySM.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Enrolled: ${_formatDate(enrollment.enrolledAt)}',
                      style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                    ),
                    if (enrollment.validUntil != null) ...[
                      const SizedBox(width: AppTheme.spacingMD),
                      Icon(
                        enrollment.isValid ? Icons.event_available : Icons.event_busy,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Expires: ${_formatDate(enrollment.validUntil!)}',
                        style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showExtendValidityDialog(enrollment),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Extend'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    OutlinedButton.icon(
                      onPressed: () => _showUpdateValidityDialog(enrollment),
                      icon: const Icon(Icons.edit_calendar, size: 16),
                      label: const Text('Set Date'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }
}
