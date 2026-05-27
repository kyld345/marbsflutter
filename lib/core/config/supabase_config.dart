// lib/core/config/supabase_config.dart

class SupabaseConfig {
  static const String supabaseUrl =
      'https://vgvihblboxqhrovzlpfc.supabase.co'; // Replace with your Supabase URL
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZndmloYmxib3hxaHJvdnpscGZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMzU0NTcsImV4cCI6MjA5MTkxMTQ1N30.zY19nuyo7EvaMSGaNreHBy-3HxhFAC5mpHhug8wnyHQ'; // Replace with your Supabase Anon Key

  // Table Names
  static const String usersTable = 'users';
  static const String rolesTable = 'roles';
  static const String barbersTable = 'barbers';
  static const String servicesTable = 'services';
  static const String appointmentsTable = 'appointments';
  static const String schedulesTable = 'schedules';
  static const String queueTable = 'queue';
  static const String reviewsTable = 'reviews';
  static const String notificationsTable = 'notifications';
  static const String branchesTable = 'branches';

  // Realtime channels
  static const String queueChannel = 'queue_changes';
  static const String appointmentsChannel = 'appointment_changes';
  static const String notificationsChannel = 'notification_changes';
}
