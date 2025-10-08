import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/google_auth_service.dart';
import '../screens/google_signin_screen.dart';

class ModernNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;

  const ModernNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  State<ModernNavBar> createState() => _ModernNavBarState();
}

class _ModernNavBarState extends State<ModernNavBar> {
  bool _isHoveringLogo = false;

  final List<_NavItem> _navItems = const [
    _NavItem(label: 'Home', icon: Icons.home),
    _NavItem(label: 'About Us', icon: Icons.info),
    _NavItem(label: 'Gallery', icon: Icons.photo_library),
    _NavItem(label: 'Courses', icon: Icons.school),
    _NavItem(label: 'Testimony', icon: Icons.star),
    _NavItem(label: 'Contact Us', icon: Icons.contact_mail),
  ];

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
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
      final authService = context.read<GoogleAuthService>();
      await authService.signOut();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GoogleSignInScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<GoogleAuthService>();
    final user = authService.currentUser;
    final isMobile = Breakpoints.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppTheme.spacingMD : AppTheme.spacingXL,
            vertical: AppTheme.spacingMD,
          ),
          child: isMobile ? _buildMobileNav(user) : _buildDesktopNav(user),
        ),
      ),
    );
  }

  Widget _buildDesktopNav(user) {
    return Row(
      children: [
        // Logo
        _buildLogo(),
        const SizedBox(width: AppTheme.spacingXL),

        // Navigation items
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _navItems.asMap().entries.map((entry) {
              return _NavButton(
                label: entry.value.label,
                icon: entry.value.icon,
                isActive: widget.currentIndex == entry.key,
                onTap: () => widget.onIndexChanged(entry.key),
              );
            }).toList(),
          ),
        ),

        const SizedBox(width: AppTheme.spacingXL),

        // User actions
        _buildUserActions(user),
      ],
    );
  }

  Widget _buildMobileNav(user) {
    return Row(
      children: [
        // Mobile menu button
        IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _showMobileMenu(user),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: AppTheme.spacingSM),

        // Logo
        _buildLogo(compact: true),

        const Spacer(),

        // User avatar
        if (user?.photoURL != null)
          GestureDetector(
            onTap: () => _showUserMenu(user),
            child: CircleAvatar(
              backgroundImage: NetworkImage(user!.photoURL!),
              radius: 18,
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _showUserMenu(user),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildLogo({bool compact = false}) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringLogo = true),
      onExit: (_) => setState(() => _isHoveringLogo = false),
      child: GestureDetector(
        onTap: () => widget.onIndexChanged(0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..scale(_isHoveringLogo ? 1.05 : 1.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Icon(
                  Icons.school,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: AppTheme.spacingSM),
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                  child: Text(
                    'E-Learning',
                    style: AppTheme.titleLG.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserActions(user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // User info with dropdown
        PopupMenuButton<String>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user?.photoURL != null)
                    CircleAvatar(
                      backgroundImage: NetworkImage(user!.photoURL!),
                      radius: 16,
                    )
                  else
                    const Icon(Icons.account_circle, size: 32),
                  const SizedBox(width: AppTheme.spacingSM),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout();
            } else if (value == 'admin') {
              Navigator.of(context).pushNamed('/admin');
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'User',
                    style: AppTheme.titleMD,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: AppTheme.bodySM.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'admin',
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: AppTheme.spacingSM),
                  Text('Admin Panel', style: TextStyle(color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: AppTheme.errorColor, size: 20),
                  SizedBox(width: AppTheme.spacingSM),
                  Text('Logout', style: TextStyle(color: AppTheme.errorColor)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showMobileMenu(user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            ..._navItems.asMap().entries.map((entry) {
              return ListTile(
                leading: Icon(
                  entry.value.icon,
                  color: widget.currentIndex == entry.key
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                ),
                title: Text(
                  entry.value.label,
                  style: TextStyle(
                    color: widget.currentIndex == entry.key
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                    fontWeight: widget.currentIndex == entry.key
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                selected: widget.currentIndex == entry.key,
                onTap: () {
                  Navigator.pop(context);
                  widget.onIndexChanged(entry.key);
                },
              );
            }),
            const Divider(),
            ListTile(
              leading: Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor),
              title: Text(
                'Admin Panel',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/admin');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
            const SizedBox(height: AppTheme.spacingLG),
          ],
        ),
      ),
    );
  }

  void _showUserMenu(user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.spacingMD),
            if (user?.photoURL != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user!.photoURL!),
                radius: 40,
              ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(user?.displayName ?? 'User', style: AppTheme.titleLG),
            Text(
              user?.email ?? '',
              style: AppTheme.bodyMD.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            const Divider(),
            ListTile(
              leading: Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor),
              title: Text(
                'Admin Panel',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).pushNamed('/admin');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
            const SizedBox(height: AppTheme.spacingLG),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSM),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMD,
            vertical: AppTheme.spacingSM,
          ),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.primaryColor.withOpacity(0.1)
                : _isHovering
                    ? AppTheme.primaryColor.withOpacity(0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isActive || _isHovering
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                widget.label,
                style: AppTheme.bodyMD.copyWith(
                  color: widget.isActive
                      ? AppTheme.primaryColor
                      : AppTheme.textPrimary,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem({
    required this.label,
    required this.icon,
  });
}
