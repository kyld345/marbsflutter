// lib/features/dashboard/presentation/barber_dashboard_screen.dart
// Barber home: today's appointments, queue status, schedule overview

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/domain/auth_provider.dart';
import '../../appointments/domain/appointment_provider.dart';
import '../../appointments/domain/appointment_model.dart';
import '../../queue/domain/queue_provider.dart';
import '../../barbers/domain/barber_provider.dart';
import '../../barbers/domain/barber_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_router.dart';
import '../../../widgets/common_widgets.dart';

class BarberDashboardScreen extends ConsumerWidget {
  const BarberDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final authUser = ref.watch(authStateProvider).value;
    final barbersAsync = ref.watch(allBarbersProvider);

    final displayName = profileAsync.value?['full_name'] as String? ?? 'Barber';
    // Use a single DateTime.now() for the whole build so every derived value
    // (greeting, filter date) is stable within this frame.
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // Find this barber's record
    final myBarber = barbersAsync.value?.firstWhere(
      (b) => b.userId == authUser?.id,
      orElse: () => barbersAsync.value!.first,
    );

    // branchId is only needed for stats — today's appts only need barberId + date
    // BUG FIX: Use a date-only DateTime so the Equatable check in
    // AppointmentFilter is stable across rebuilds. DateTime.now() changes
    // every millisecond → different ISO string → new provider → infinite loading.
    final todayApptAsync = myBarber != null
        ? ref.watch(allAppointmentsProvider(AppointmentFilter(
            barberId: myBarber.id,
            date: DateTime(now.year, now.month, now.day),
          )))
        : null;

    final queueAsync = ref.watch(todayQueueProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.content_cut,
                                  color: AppTheme.secondary, size: 12),
                              const SizedBox(width: 4),
                              Text('BARBER',
                                  style: GoogleFonts.dmSans(
                                    color: AppTheme.secondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$greeting,',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 14),
                    ),
                    Text(
                      displayName,
                      style: GoogleFonts.playfairDisplay(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(DateTime.now()),
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Availability toggle
                  if (myBarber != null)
                    _AvailabilityCard(barber: myBarber)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1),

                  const SizedBox(height: 20),

                  // Quick stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.calendar_today,
                          label: 'Today',
                          value:
                              todayApptAsync?.value?.length.toString() ?? '—',
                          color: AppTheme.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: queueAsync.when(
                          data: (queue) {
                            final myQueue = myBarber == null
                                ? queue
                                : queue.where((q) {
                                    // Could filter by barber from appointment
                                    return true;
                                  }).toList();
                            final waiting = myQueue
                                .where((q) => q.status == 'waiting')
                                .length;
                            return _StatCard(
                              icon: Icons.queue,
                              label: 'In Queue',
                              value: '$waiting',
                              color: AppTheme.warning,
                            );
                          },
                          loading: () => const _StatCard(
                              icon: Icons.queue,
                              label: 'In Queue',
                              value: '—',
                              color: AppTheme.warning),
                          error: (_, __) => const _StatCard(
                              icon: Icons.queue,
                              label: 'In Queue',
                              value: '—',
                              color: AppTheme.warning),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.star,
                          label: 'Rating',
                          value: myBarber?.rating.toStringAsFixed(1) ?? '—',
                          color: AppTheme.secondary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),

                  // Quick actions
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.playfairDisplay(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.calendar_today,
                          label: 'My Appointments',
                          onTap: () => context.go(AppRoutes.barberAppointments),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.queue,
                          label: 'View Queue',
                          onTap: () => context.go(AppRoutes.barberQueue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.calendar_month,
                          label: 'My Schedule',
                          onTap: () => context.go(AppRoutes.barberSchedule),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.person,
                          label: 'My Profile',
                          onTap: () => context.go(AppRoutes.barberProfile),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 24),

                  // Today's appointments list
                  Text(
                    'Today\'s Appointments',
                    style: GoogleFonts.playfairDisplay(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (todayApptAsync == null)
                    _buildEmptyState(
                        'No barber profile linked to your account.')
                  else
                    todayApptAsync.when(
                      data: (appointments) {
                        if (appointments.isEmpty) {
                          return _buildEmptyState(
                              'No appointments scheduled for today. Enjoy your day!');
                        }
                        return Column(
                          children: appointments
                              .map((a) => _AppointmentTile(appointment: a))
                              .toList(),
                        );
                      },
                      loading: () => const LoadingWidget(),
                      error: (e, _) =>
                          _buildEmptyState('Could not load appointments.'),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_today_outlined,
              color: AppTheme.textHint, size: 40),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 14)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────

class _AvailabilityCard extends ConsumerWidget {
  final BarberModel barber;
  const _AvailabilityCard({required this.barber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: barber.isAvailable
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: barber.isAvailable
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            barber.isAvailable ? Icons.circle : Icons.circle,
            color: barber.isAvailable ? AppTheme.success : AppTheme.error,
            size: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  barber.isAvailable ? 'Available for bookings' : 'Unavailable',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'You are ${barber.isAvailable ? 'accepting' : 'not accepting'} new appointments',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: barber.isAvailable,
            onChanged: (val) {
              // Toggle availability in DB
              ref
                  .read(barberNotifierProvider.notifier)
                  .toggleAvailability(barber.id, val);
            },
            activeThumbColor: AppTheme.secondary,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: AppTheme.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E2A3A)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: AppTheme.textHint, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final AppointmentModel appointment;
  const _AppointmentTile({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appointment.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  appointment.appointmentTime.substring(0, 5),
                  style: GoogleFonts.dmSans(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.customerName ?? 'Customer',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  appointment.serviceName ?? 'Service',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              appointment.status.replaceAll('_', ' ').toUpperCase(),
              style: GoogleFonts.dmSans(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'confirmed':
        return AppTheme.info;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.textHint;
    }
  }
}