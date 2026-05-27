// lib/widgets/web_shell.dart
// FIXED: Added "Users" nav item for admins only, fixed route active-state detection,
//        receptionist home route set correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../features/auth/domain/auth_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/responsive.dart';
import '../routes/app_router.dart';

class WebShell extends ConsumerStatefulWidget {
  final Widget child;
  const WebShell({super.key, required this.child});

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<WebShell> {
  bool _sidebarExpanded = true;

  // GlobalKey lets us open the drawer from the bottom nav without needing
  // a BuildContext that's a descendant of the Scaffold.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // All possible nav items
  static const List<_NavItem> _adminItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', AppRoutes.dashboard),
    _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Appointments', AppRoutes.webAppointments),
    _NavItem(Icons.queue_outlined, Icons.queue, 'Queue', AppRoutes.webQueue),
    _NavItem(Icons.people_outline, Icons.people, 'Customers', AppRoutes.customers),
    _NavItem(Icons.content_cut, Icons.content_cut, 'Barbers', AppRoutes.barbers),
    _NavItem(Icons.spa_outlined, Icons.spa, 'Services', AppRoutes.services),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Schedules', AppRoutes.schedules),
    _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'Reports', AppRoutes.reports),
    _NavItem(Icons.manage_accounts_outlined, Icons.manage_accounts, 'Users', AppRoutes.usersManagement),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings', AppRoutes.settings),
  ];

  static const List<_NavItem> _receptionistItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', AppRoutes.receptionistHome),
    _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Appointments', AppRoutes.webAppointments),
    _NavItem(Icons.queue_outlined, Icons.queue, 'Queue', AppRoutes.webQueue),
    _NavItem(Icons.people_outline, Icons.people, 'Customers', AppRoutes.customers),
    _NavItem(Icons.content_cut, Icons.content_cut, 'Barbers', AppRoutes.barbers),
    _NavItem(Icons.spa_outlined, Icons.spa, 'Services', AppRoutes.services),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Schedules', AppRoutes.schedules),
    _NavItem(Icons.settings_outlined, Icons.settings, 'Settings', AppRoutes.settings),
  ];

  static const List<_NavItem> _barberItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', AppRoutes.barberDashboard),
    _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Appointments', AppRoutes.barberAppointments),
    _NavItem(Icons.queue_outlined, Icons.queue, 'My Queue', AppRoutes.barberQueue),
    _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'My Schedule', AppRoutes.barberSchedule),
    _NavItem(Icons.person_outline, Icons.person, 'Profile', AppRoutes.barberProfile),
  ];

  List<_NavItem> _navItemsForRole(String role) {
    switch (role.trim().toLowerCase()) {
      case AppConstants.roleAdmin:
        return _adminItems;
      case AppConstants.roleReceptionist:
        return _receptionistItems;
      case AppConstants.roleBarber:
        return _barberItems;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final location = GoRouterState.of(context).uri.toString();
    final profileAsync = ref.watch(userProfileProvider);
    final role = ref.watch(userRoleProvider);

    if (isMobile) {
      // BUG FIX: The previous mobile layout added its own AppBar on top of
      // the child screens (AdminDashboard etc.) which also have their own
      // Scaffold + AppBar, causing two AppBars stacked — "sabog" on mobile.
      //
      // Fix: Remove the outer AppBar entirely. The child screens' own AppBars
      // are the only ones rendered. Navigation is provided via a role-aware
      // BottomNavigationBar. Overflow items remain accessible via the drawer,
      // opened from the "More" tab.
      return Scaffold(
        key: _scaffoldKey,
        drawer: _buildSidebarDrawer(location, profileAsync, role),
        body: widget.child,
        bottomNavigationBar: _buildMobileBottomNav(location, role),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _sidebarExpanded ? 240 : 72,
            child: _buildSidebar(location, profileAsync, role),
          ),
          // Divider
          Container(width: 1, color: const Color(0xFF1E2A3A)),
          // Main content
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  // ── Mobile bottom navigation ──────────────────────────────────
  // Shows the most-used routes as tabs; "More" opens the full drawer.
  Widget _buildMobileBottomNav(String location, String role) {
    final items = _mobileNavItemsForRole(role);
    final currentIdx = _mobileActiveIndex(location, items);

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.secondary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
                color: AppTheme.secondary, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppTheme.secondary, size: 22);
          }
          return const IconThemeData(color: AppTheme.textHint, size: 22);
        }),
      ),
      child: NavigationBar(
        selectedIndex: currentIdx,
        onDestinationSelected: (i) {
          final item = items[i];
          if (item.route == '__drawer__') {
            // "More" tab — open the full sidebar drawer
            _scaffoldKey.currentState?.openDrawer();
          } else {
            context.go(item.route);
          }
        },
        destinations: items.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }

  // Returns the selected tab index; -1 falls back to 0.
  int _mobileActiveIndex(String location, List<_NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      final route = items[i].route;
      if (route == '__drawer__') continue;
      if (_isActiveRoute(location, route)) return i;
    }
    return 0;
  }

  List<_NavItem> _mobileNavItemsForRole(String role) {
    switch (role.trim().toLowerCase()) {
      case AppConstants.roleAdmin:
        return const [
          _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', AppRoutes.dashboard),
          _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Appts', AppRoutes.webAppointments),
          _NavItem(Icons.queue_outlined, Icons.queue, 'Queue', AppRoutes.webQueue),
          _NavItem(Icons.people_outline, Icons.people, 'Customers', AppRoutes.customers),
          _NavItem(Icons.menu, Icons.menu, 'More', '__drawer__'),
        ];
      case AppConstants.roleReceptionist:
        return const [
          _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', AppRoutes.receptionistHome),
          _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Appts', AppRoutes.webAppointments),
          _NavItem(Icons.queue_outlined, Icons.queue, 'Queue', AppRoutes.webQueue),
          _NavItem(Icons.people_outline, Icons.people, 'Customers', AppRoutes.customers),
          _NavItem(Icons.menu, Icons.menu, 'More', '__drawer__'),
        ];
      case AppConstants.roleBarber:
      default:
        return const [
          _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', AppRoutes.barberDashboard),
          _NavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Appts', AppRoutes.barberAppointments),
          _NavItem(Icons.queue_outlined, Icons.queue, 'Queue', AppRoutes.barberQueue),
          _NavItem(Icons.calendar_month_outlined, Icons.calendar_month, 'Schedule', AppRoutes.barberSchedule),
          _NavItem(Icons.person_outline, Icons.person, 'Profile', AppRoutes.barberProfile),
        ];
    }
  }

  Widget _buildSidebar(
    String location,
    AsyncValue<Map<String, dynamic>?> profileAsync,
    String role,
  ) {
    final items = _navItemsForRole(role);

    return Container(
      color: AppTheme.surface,
      child: Column(
        children: [
          // Logo & collapse toggle
          Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.content_cut, color: AppTheme.secondary, size: 18),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Marbin',
                      style: GoogleFonts.playfairDisplay(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _sidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                    color: AppTheme.textHint,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: items.map((item) {
                // Active if location starts with route (but avoid false matches)
                final isActive = _isActiveRoute(location, item.route);
                return _buildNavItem(item, isActive);
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // User profile section
          _buildUserSection(profileAsync, role),
        ],
      ),
    );
  }

  bool _isActiveRoute(String location, String route) {
    if (route == AppRoutes.dashboard) return location == route;
    if (route == AppRoutes.receptionistHome) return location == route;
    if (route == AppRoutes.barberDashboard) return location == route;
    return location.startsWith(route);
  }

  Widget _buildNavItem(_NavItem item, bool isActive) {
    return Tooltip(
      message: _sidebarExpanded ? '' : item.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.secondary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppTheme.secondary.withValues(alpha: 0.2))
              : null,
        ),
        child: ListTile(
          dense: true,
          minLeadingWidth: 0,
          contentPadding: EdgeInsets.symmetric(
            horizontal: _sidebarExpanded ? 12 : 8,
            vertical: 2,
          ),
          leading: Icon(
            isActive ? item.activeIcon : item.icon,
            color: isActive ? AppTheme.secondary : AppTheme.textHint,
            size: 20,
          ),
          title: _sidebarExpanded
              ? Text(
                  item.label,
                  style: GoogleFonts.dmSans(
                    color: isActive ? AppTheme.secondary : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                )
              : null,
          onTap: () => context.go(item.route),
        ),
      ),
    );
  }

  Widget _buildUserSection(
      AsyncValue<Map<String, dynamic>?> profileAsync, String role) {
    final name = profileAsync.value?['full_name'] as String? ?? 'User';

    return InkWell(
      onTap: () {
        final settingsRoute = role == AppConstants.roleBarber
            ? AppRoutes.barberProfile
            : AppRoutes.settings;
        context.go(settingsRoute);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _roleColor(role).withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: GoogleFonts.dmSans(
                    color: _roleColor(role), fontWeight: FontWeight.w700),
              ),
            ),
            if (_sidebarExpanded) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.textHint, size: 18),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                },
                tooltip: 'Sign Out',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarDrawer(
    String location,
    AsyncValue<Map<String, dynamic>?> profileAsync,
    String role,
  ) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: _buildSidebar(location, profileAsync, role),
    );
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case AppConstants.roleAdmin: return AppTheme.secondary;
      case AppConstants.roleReceptionist: return AppTheme.info;
      case AppConstants.roleBarber: return Colors.purple;
      default: return AppTheme.success;
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.activeIcon, this.label, this.route);
}