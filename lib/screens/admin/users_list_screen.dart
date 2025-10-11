import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/admin_user_service.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final AdminUserService _userService = AdminUserService();
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          return user.name.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query) ||
              user.role.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlock(UserModel user) async {
    final action = user.isBlocked ? 'unblock' : 'block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} User'),
        content: Text('Are you sure you want to $action ${user.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isBlocked ? AppTheme.successColor : AppTheme.errorColor,
            ),
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = user.isBlocked
          ? await _userService.unblockUser(user.id)
          : await _userService.blockUser(user.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user.isBlocked ? "unblocked" : "blocked"}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadUsers();
      }
    }
  }

  Future<void> _viewUserDetails(UserModel user) async {
    final enrollments = await _userService.getUserEnrollments(user.id);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(user.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Role', user.role.name.toUpperCase()),
                _buildDetailRow('Status', user.isBlocked ? 'BLOCKED' : 'ACTIVE'),
                _buildDetailRow('Premium', user.isPremium ? 'YES' : 'NO'),
                _buildDetailRow('Joined', _formatDate(user.createdAt)),
                const Divider(height: AppTheme.spacingLG),
                Text('Enrollments (${enrollments.length})', style: AppTheme.titleMD),
                const SizedBox(height: AppTheme.spacingSM),
                ...enrollments.map((e) {
                  // Determine enrollment status
                  Color chipColor;
                  IconData statusIcon;
                  String statusText;

                  if (e.status != 'approved') {
                    chipColor = Colors.grey;
                    statusIcon = Icons.pending;
                    statusText = e.status.toUpperCase();
                  } else if (e.isValid) {
                    chipColor = const Color(0xFF10B981); // Green
                    statusIcon = Icons.check_circle;
                    statusText = 'LIVE';
                    if (e.isExpiringSoon) {
                      chipColor = const Color(0xFFF59E0B); // Orange
                      statusIcon = Icons.warning;
                      statusText = 'EXPIRING SOON';
                    }
                  } else {
                    chipColor = const Color(0xFFEF4444); // Red
                    statusIcon = Icons.cancel;
                    statusText = 'EXPIRED';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingSM),
                      decoration: BoxDecoration(
                        color: chipColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(color: chipColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.courseTitle,
                                  style: AppTheme.bodyMD.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(statusIcon, size: 16, color: chipColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: AppTheme.bodySM.copyWith(
                                  color: chipColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (e.validUntil != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Valid until: ${_formatDate(e.validUntil!)}',
                              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
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
          else if (_users.isEmpty)
            const Expanded(child: Center(child: Text('No users found')))
          else if (_filteredUsers.isEmpty)
            const Expanded(child: Center(child: Text('No users match your search')))
          else
            Expanded(child: _buildUsersList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = Breakpoints.isMobile(context);

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
              Text('Users (${_users.length})', style: AppTheme.titleLG),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadUsers,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          SizedBox(
            width: isMobile ? double.infinity : 400,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or role...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM,
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingSM),
              child: Text(
                'Showing ${_filteredUsers.length} of ${_users.length} users',
                style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null ? Text(user.name[0].toUpperCase()) : null,
            ),
            title: Text(user.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        user.role.name.toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      backgroundColor: user.isAdmin
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.grey[200],
                    ),
                    const SizedBox(width: 4),
                    if (user.isBlocked)
                      const Chip(
                        label: Text('BLOCKED', style: TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        backgroundColor: AppTheme.errorColor,
                      ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View Details')),
                PopupMenuItem(
                  value: 'block',
                  child: Text(user.isBlocked ? 'Unblock' : 'Block'),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _viewUserDetails(user);
                    break;
                  case 'block':
                    _toggleBlock(user);
                    break;
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTheme.bodyMD),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
