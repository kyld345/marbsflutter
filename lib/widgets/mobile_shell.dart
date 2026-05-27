// lib/widgets/mobile_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:badges/badges.dart' as badges;
import '../features/notifications/domain/notification_provider.dart';
import '../core/theme/app_theme.dart';
import '../routes/app_router.dart';

class MobileShell extends ConsumerWidget {
  final Widget child;
  const MobileShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final unreadCount = unreadAsync.value ?? 0;

    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _getIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.secondary.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.dmSans(
                color: AppTheme.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return GoogleFonts.dmSans(
              color: AppTheme.textHint,
              fontSize: 11,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppTheme.secondary, size: 22);
            }
            return const IconThemeData(color: AppTheme.textHint, size: 22);
          }),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) => _navigate(context, index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Bookings',
            ),
            const NavigationDestination(
              icon: Icon(Icons.queue_outlined),
              selectedIcon: Icon(Icons.queue),
              label: 'Queue',
            ),
            NavigationDestination(
              icon: badges.Badge(
                showBadge: unreadCount > 0,
                badgeContent: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: AppTheme.error,
                  padding: EdgeInsets.all(4),
                ),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: badges.Badge(
                showBadge: unreadCount > 0,
                badgeContent: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: AppTheme.error,
                  padding: EdgeInsets.all(4),
                ),
                child: const Icon(Icons.notifications),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  int _getIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/appointments')) return 1;
    if (location.startsWith('/queue')) return 2;
    if (location.startsWith('/notifications')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.customerHome);
        break;
      case 1:
        context.go(AppRoutes.customerAppointments);
        break;
      case 2:
        context.go(AppRoutes.queue);
        break;
      case 3:
        context.go(AppRoutes.customerNotifications);
        break;
      case 4:
        context.go(AppRoutes.customerProfile);
        break;
    }
  }
}
