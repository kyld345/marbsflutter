// lib/features/dashboard/presentation/customer_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/domain/auth_provider.dart';
import '../../appointments/domain/appointment_provider.dart';
import '../../appointments/domain/appointment_model.dart';
import '../../notifications/domain/notification_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_router.dart';
import '../../../widgets/common_widgets.dart';

class CustomerDashboardScreen extends ConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final profileAsync = ref.watch(userProfileProvider);
    final appointmentsAsync =
        ref.watch(customerAppointmentsProvider('pending'));
    final unreadAsync = ref.watch(unreadCountProvider);

    final displayName = profileAsync.value?['full_name'] as String? ??
        user?.email?.split('@').first ??
        'Customer';

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Custom app bar
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, Color(0xFF1A2B4A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$greeting,',
                                  style: GoogleFonts.dmSans(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14),
                                ),
                                Text(
                                  displayName,
                                  style: GoogleFonts.playfairDisplay(
                                    color: AppTheme.textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Stack(
                              children: [
                                IconButton(
                                  onPressed: () =>
                                      context.go(AppRoutes.customerNotifications),
                                  icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: AppTheme.textPrimary,
                                      size: 28),
                                ),
                                unreadAsync.when(
                                  data: (count) => count > 0
                                      ? Positioned(
                                          right: 6,
                                          top: 6,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: AppTheme.error,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                count > 9 ? '9+' : '$count',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700),
                                              ),
                                            ),
                                          ),
                                        )
                                      : const SizedBox(),
                                  loading: () => const SizedBox(),
                                  error: (_, __) => const SizedBox(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick actions
                  _buildQuickActions(context).animate().fadeIn().slideY(begin: 0.1),
                  const SizedBox(height: 24),

                  // Upcoming appointments
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming',
                        style: GoogleFonts.playfairDisplay(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go(AppRoutes.customerAppointments),
                        child: Text('See all',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.secondary)),
                      ),
                    ],
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 12),

                  appointmentsAsync.when(
                    data: (appointments) {
                      if (appointments.isEmpty) {
                        return _buildNoAppointments(context);
                      }
                      return Column(
                        children: appointments.take(3).toList().asMap().entries
                            .map((e) => _buildUpcomingCard(
                                  context,
                                  e.value,
                                  e.key,
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const LoadingWidget(),
                    error: (e, _) => const SizedBox(),
                  ),

                  const SizedBox(height: 24),

                  // Services promo section
                  _buildPromoSection(context)
                      .animate()
                      .fadeIn(delay: 300.ms),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'icon': Icons.calendar_today,
        'label': 'My\nBookings',
        'route': AppRoutes.customerAppointments,
        'color': AppTheme.info,
      },
      {
        'icon': Icons.queue,
        'label': 'Live\nQueue',
        'route': AppRoutes.queue,
        'color': AppTheme.statusInProgressColor,
      },
      {
        'icon': Icons.content_cut,
        'label': 'Book\nNow',
        'route': AppRoutes.bookAppointment,
        'color': AppTheme.secondary,
      },
      {
        'icon': Icons.person_outline,
        'label': 'My\nProfile',
        'route': AppRoutes.customerProfile,
        'color': AppTheme.success,
      },
    ];

    return Row(
      children: actions.map((action) {
        final color = action['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () => context.go(action['route'] as String),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(action['icon'] as IconData, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    action['label'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUpcomingCard(
      BuildContext context, AppointmentModel apt, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/appointments/${apt.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                  color: AppTheme.getStatusColor(apt.status), width: 4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.content_cut,
                    color: AppTheme.secondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.serviceName ?? 'Service',
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        )),
                    Text('${apt.formattedDate} • ${apt.formattedTime}',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    Text('with ${apt.barberName ?? 'Barber'}',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textHint, fontSize: 12)),
                  ],
                ),
              ),
              StatusBadge(status: apt.status),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: (200 + index * 80).ms);
  }

  Widget _buildNoAppointments(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text('No upcoming appointments',
              style: GoogleFonts.dmSans(
                  color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.bookAppointment),
            child: const Text('Book Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF1A2B4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Your Next\nAppointment',
                  style: GoogleFonts.playfairDisplay(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fresh cuts, expert barbers, your style.',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.bookAppointment),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Book Now'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.content_cut,
                color: AppTheme.secondary, size: 40),
          ),
        ],
      ),
    );
  }
}