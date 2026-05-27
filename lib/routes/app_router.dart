// lib/routes/app_router.dart
// FIXED: Uses refreshListenable so router is created ONCE.
// Redirect uses ref.read (not ref.watch) to avoid stale closure issues.
// Role-based routing is fully enforced — each role sees only their routes.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/domain/auth_provider.dart';
// adminCreationInProgressProvider is defined in auth_provider.dart
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/dashboard/presentation/customer_dashboard_screen.dart';
import '../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../features/dashboard/presentation/barber_dashboard_screen.dart';
import '../features/dashboard/presentation/receptionist_dashboard_screen.dart';
import '../features/appointments/presentation/appointment_list_screen.dart';
import '../features/appointments/presentation/book_appointment_screen.dart';
import '../features/appointments/presentation/appointment_detail_screen.dart';
import '../features/queue/presentation/queue_screen.dart';
import '../features/barbers/presentation/barbers_screen.dart';
import '../features/services/presentation/services_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/schedules/presentation/schedules_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/reviews/presentation/reviews_screen.dart';
import '../features/users/presentation/users_management_screen.dart';
import '../widgets/mobile_shell.dart';
import '../widgets/web_shell.dart';
import '../core/constants/app_constants.dart';

// ============================================================
// ROUTE CONSTANTS
// ============================================================
class AppRoutes {
  // Auth
  static const String login = '/login';
  static const String register = '/register';

  // Customer (mobile shell)
  static const String customerHome = '/home';
  static const String customerAppointments = '/appointments';
  static const String bookAppointment = '/appointments/book';
  static const String appointmentDetail = '/appointments/:id';
  static const String queue = '/queue';
  static const String customerNotifications = '/notifications';
  static const String customerProfile = '/profile';
  static const String reviews = '/reviews';

  // Admin (web shell)
  static const String dashboard = '/dashboard';
  static const String webAppointments = '/web/appointments';
  static const String webQueue = '/web/queue';
  static const String customers = '/web/customers';
  static const String barbers = '/web/barbers';
  static const String services = '/web/services';
  static const String schedules = '/web/schedules';
  static const String reports = '/web/reports';
  static const String settings = '/web/settings';
  static const String usersManagement = '/web/users';

  // Receptionist (web shell)
  static const String receptionistHome = '/receptionist';

  // Barber (web shell)
  static const String barberDashboard = '/barber/dashboard';
  static const String barberAppointments = '/barber/appointments';
  static const String barberQueue = '/barber/queue';
  static const String barberSchedule = '/barber/schedule';
  static const String barberProfile = '/barber/profile';
}

// ============================================================
// ROLE → HOME ROUTE MAPPING
// ============================================================
String getHomeRouteForRole(String role) {
  switch (role.trim().toLowerCase()) {
    case AppConstants.roleAdmin:
      return AppRoutes.dashboard;
    case AppConstants.roleReceptionist:
      return AppRoutes.receptionistHome;
    case AppConstants.roleBarber:
      return AppRoutes.barberDashboard;
    default:
      return AppRoutes.customerHome;
  }
}

// ============================================================
// ROUTE PERMISSIONS PER ROLE
  // ============================================================
  bool isRouteAllowedForRole(String path, String role) {
    final normalized = role.trim().toLowerCase();

    // Auth routes — allowed for all (router handles logged-in redirect)
    if (path == AppRoutes.login || path == AppRoutes.register) return true;

    // Appointment detail — dynamic path check
    if (path.startsWith('/appointments/') &&
        path != AppRoutes.customerAppointments) {
      return normalized == AppConstants.roleCustomer;
    }

  switch (normalized) {
    case AppConstants.roleCustomer:
      return {
        AppRoutes.customerHome,
        AppRoutes.customerAppointments,
        AppRoutes.bookAppointment,
        AppRoutes.queue,
        AppRoutes.customerNotifications,
        AppRoutes.customerProfile,
        AppRoutes.reviews,
      }.contains(path);

    case AppConstants.roleAdmin:
      return {
        AppRoutes.dashboard,
        AppRoutes.webAppointments,
        AppRoutes.webQueue,
        AppRoutes.customers,
        AppRoutes.barbers,
        AppRoutes.services,
        AppRoutes.schedules,
        AppRoutes.reports,
        AppRoutes.settings,
        AppRoutes.usersManagement,
      }.contains(path);

    case AppConstants.roleReceptionist:
      return {
        AppRoutes.receptionistHome,
        AppRoutes.webAppointments,
        AppRoutes.webQueue,
        AppRoutes.customers,
        AppRoutes.barbers,
        AppRoutes.services,
        AppRoutes.schedules,
        AppRoutes.settings,
      }.contains(path);

    case AppConstants.roleBarber:
      return {
        AppRoutes.barberDashboard,
        AppRoutes.barberAppointments,
        AppRoutes.barberQueue,
        AppRoutes.barberSchedule,
        AppRoutes.barberProfile,
      }.contains(path);
  }

  return false;
}

// ============================================================
// ROUTER PROVIDER
// FIXED: Single GoRouter instance with refreshListenable.
// ============================================================
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation:  AppRoutes.login,
    refreshListenable: refreshNotifier,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      // FIX: While admin is creating a barber account, signUp() fires an auth
      // state change that would redirect the admin out of the barbers page.
      // Suppressing the redirect here keeps the admin on their current page
      // until the creation finishes and the admin session is restored.
      final creationInProgress = ref.read(adminCreationInProgressProvider);
      if (creationInProgress) return null;

      // Use ref.read (not watch) — this callback is triggered by refreshListenable
      final authState = ref.read(authStateProvider);
      final roleState = ref.read(userRoleAsyncProvider);

      // While auth is loading, don't redirect
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final currentPath = state.matchedLocation;
      final isAuthRoute =
          currentPath == AppRoutes.login || currentPath == AppRoutes.register;

      // Not logged in → go to login
      if (!isLoggedIn) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      // Logged in, role still loading → stay put (don't redirect yet)
      if (roleState.isLoading) return null;

      final role = roleState.value ?? AppConstants.roleCustomer;
      final homeRoute = getHomeRouteForRole(role);

      // On auth route while logged in → go to role home
      if (isAuthRoute) return homeRoute;

      // On wrong route for this role → redirect to role home
      if (!isRouteAllowedForRole(currentPath, role)) {
        return homeRoute;
      }

      return null; // No redirect needed
    },

    routes: [
      // ── AUTH ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // ── CUSTOMER (mobile shell) ───────────────────────────
      ShellRoute(
        builder: (context, state, child) => MobileShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.customerHome,
            builder: (context, state) => const CustomerDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.customerAppointments,
            builder: (context, state) => const AppointmentListScreen(),
          ),
          GoRoute(
            path: AppRoutes.bookAppointment,
            builder: (context, state) => const BookAppointmentScreen(),
          ),
          GoRoute(
            path: '/appointments/:id',
            builder: (context, state) => AppointmentDetailScreen(
              appointmentId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: AppRoutes.queue,
            builder: (context, state) => const QueueScreen(),
          ),
          GoRoute(
            path: AppRoutes.customerNotifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.customerProfile,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.reviews,
            builder: (context, state) => const ReviewsScreen(),
          ),
        ],
      ),

      // ── ADMIN (web shell) ─────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => WebShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.webAppointments,
            builder: (context, state) =>
                const AppointmentListScreen(isWebView: true),
          ),
          GoRoute(
            path: AppRoutes.webQueue,
            builder: (context, state) => const QueueScreen(isWebView: true),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomersScreen(),
          ),
          GoRoute(
            path: AppRoutes.barbers,
            builder: (context, state) => const BarbersScreen(),
          ),
          GoRoute(
            path: AppRoutes.services,
            builder: (context, state) => const ServicesScreen(),
          ),
          GoRoute(
            path: AppRoutes.schedules,
            builder: (context, state) => const SchedulesScreen(),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: AppRoutes.usersManagement,
            builder: (context, state) => const UsersManagementScreen(),
          ),
          // Receptionist home
          GoRoute(
            path: AppRoutes.receptionistHome,
            builder: (context, state) => const ReceptionistDashboardScreen(),
          ),
        ],
      ),

      // ── BARBER (web shell) ────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => WebShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.barberDashboard,
            builder: (context, state) => const BarberDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.barberAppointments,
            builder: (context, state) =>
                const AppointmentListScreen(isWebView: true, barberView: true),
          ),
          GoRoute(
            path: AppRoutes.barberQueue,
            builder: (context, state) =>
                const QueueScreen(isWebView: true, barberView: true),
          ),
          GoRoute(
            path: AppRoutes.barberSchedule,
            builder: (context, state) => const SchedulesScreen(),
          ),
          GoRoute(
            path: AppRoutes.barberProfile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFD4AF37)),
            const SizedBox(height: 16),
            const Text(
              'Page not found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Back to Login',
                  style: TextStyle(color: Color(0xFFD4AF37))),
            ),
          ],
        ),
      ),
    ),
  );
});
