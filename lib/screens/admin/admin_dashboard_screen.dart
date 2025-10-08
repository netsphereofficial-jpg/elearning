import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';
import '../../services/admin_auth_service.dart';
import 'admin_login_screen.dart';
import 'dashboard_overview_screen.dart';
import 'courses_list_screen.dart';
import 'payments_list_screen.dart';
import 'users_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminAuthService _authService = AdminAuthService();
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      description: 'Overview & Stats',
    ),
    _NavItem(
      icon: Icons.school,
      label: 'Courses',
      description: 'Manage Courses',
    ),
    _NavItem(
      icon: Icons.payment,
      label: 'Payments',
      description: 'Approve Payments',
    ),
    _NavItem(
      icon: Icons.people,
      label: 'Users',
      description: 'User Management',
    ),
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const DashboardOverviewScreen(),
      const CoursesListScreen(),
      const PaymentsListScreen(),
      const UsersListScreen(),
    ];
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from admin panel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Breakpoints.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: isMobile ? _buildDrawer() : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(
          right: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingLG),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSM),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                const Expanded(
                  child: Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                return _buildNavItem(_navItems[index], index);
              },
            ),
          ),

          // Logout button
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                return _buildNavItem(_navItems[index], index, inDrawer: true);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop(); // Close drawer
                _handleLogout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, {bool inDrawer = false}) {
    final isSelected = _selectedIndex == index;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: inDrawer ? 0 : AppTheme.spacingSM,
        vertical: 2,
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          item.description,
          style: AppTheme.bodySM.copyWith(color: AppTheme.textSecondary),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          if (inDrawer && mounted) {
            Navigator.of(context).pop(); // Close drawer
          }
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String description;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.description,
  });
}
