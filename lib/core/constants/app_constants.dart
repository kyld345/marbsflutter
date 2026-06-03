// lib/core/constants/app_constants.dart

class AppConstants {
  // App Info
  static const String appName = 'kyl';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your Style, Our Craft';

  // User Roles
  static const String roleCustomer = 'customer';
  static const String roleBarber = 'barber';
  static const String roleReceptionist = 'receptionist';
  static const String roleAdmin = 'admin';

  // Appointment Statuses
  static const String statusPending = 'pending';
  static const String statusConfirmed = 'confirmed';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';
  static const String statusNoShow = 'no_show';

  // Queue Statuses
  static const String queueWaiting = 'waiting';
  static const String queueInProgress = 'in_progress';
  static const String queueCompleted = 'completed';
  static const String queueCancelled = 'cancelled';
  static const String queueSkipped = 'skipped';

  // Payment Statuses
  static const String paymentUnpaid = 'unpaid';
  static const String paymentPaid = 'paid';
  static const String paymentRefunded = 'refunded';

  // Notification Types
  static const String notifAppointment = 'appointment';
  static const String notifQueue = 'queue';
  static const String notifPromotion = 'promotion';
  static const String notifSystem = 'system';

  // Days of Week
  static const List<String> daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  // Pagination
  static const int defaultPageSize = 20;

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
}

class AppStrings {
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to your account';
  static const String registerTitle = 'Create Account';
  static const String registerSubtitle = 'kyl Barbershop welcomes you';
  static const String forgotPassword = 'Forgot Password?';
  static const String noAccount = "Don't have an account? ";
  static const String hasAccount = 'Already have an account? ';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';
  static const String signOut = 'Sign Out';
  static const String bookAppointment = 'Book Appointment';
  static const String viewQueue = 'View Queue';
  static const String myAppointments = 'My Appointments';
  static const String notifications = 'Notifications';
  static const String profile = 'Profile';
}
