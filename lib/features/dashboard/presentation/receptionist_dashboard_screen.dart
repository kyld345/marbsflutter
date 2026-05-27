// lib/features/dashboard/presentation/receptionist_dashboard_screen.dart
// Receptionist home: walk-in check-in, queue overview, today's appointments

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
import '../../queue/domain/queue_model.dart';
import '../../barbers/domain/barber_provider.dart';
import '../../services/domain/service_provider.dart';
import '../../services/domain/service_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/branch_provider.dart';
import '../../../routes/app_router.dart';
import '../../../widgets/common_widgets.dart';

class ReceptionistDashboardScreen extends ConsumerWidget {
  const ReceptionistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final queueAsync = ref.watch(todayQueueProvider);
    final queueStatsAsync = ref.watch(queueStatsProvider);
    final branchId = ref.watch(activeBranchIdProvider).value;
    // BUG FIX: Use date-only DateTime so AppointmentFilter's Equatable check
    // is stable across rebuilds. DateTime.now() changes every millisecond →
    // different ISO string → new provider instance → infinite loading.
    final now = DateTime.now();
    final todayFilter = AppointmentFilter(date: DateTime(now.year, now.month, now.day));
    final todayApptAsync = ref.watch(allAppointmentsProvider(todayFilter));

    final displayName =
        profileAsync.value?['full_name'] as String? ?? 'Receptionist';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.invalidate(todayQueueProvider);
                  ref.invalidate(queueStatsProvider);
                  ref.invalidate(allAppointmentsProvider);
                },
              ),
            ],
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
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      _RoleBadge('RECEPTIONIST'),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome, $displayName',
                      style: GoogleFonts.playfairDisplay(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(now),
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
                  // Stats row
                  queueStatsAsync
                      .when(
                        data: (stats) => _buildStatsRow(stats, todayApptAsync),
                        loading: () => const LoadingWidget(),
                        error: (_, __) => const SizedBox(),
                      )
                      .animate()
                      .fadeIn(),

                  const SizedBox(height: 24),

                  // Quick actions
                  Text('Quick Actions',
                      style: GoogleFonts.playfairDisplay(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 12),
                  _buildQuickActions(context, ref, branchId)
                      .animate()
                      .fadeIn(delay: 100.ms),

                  const SizedBox(height: 24),

                  // Live queue
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Live Queue',
                          style: GoogleFonts.playfairDisplay(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          )),
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.webQueue),
                        icon: const Icon(Icons.open_in_new,
                            color: AppTheme.secondary, size: 16),
                        label: Text('Manage',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.secondary, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  queueAsync
                      .when(
                        data: (queue) {
                          final waiting = queue
                              .where((q) => q.status == 'waiting')
                              .toList();
                          if (waiting.isEmpty) {
                            return _buildEmptyCard('No one in queue right now');
                          }
                          return Column(
                            children: waiting
                                .take(5)
                                .map((q) => _QueueTile(entry: q))
                                .toList(),
                          );
                        },
                        loading: () => const LoadingWidget(),
                        error: (_, __) =>
                            _buildEmptyCard('Unable to load queue'),
                      )
                      .animate()
                      .fadeIn(delay: 200.ms),

                  const SizedBox(height: 24),

                  // Today's appointments
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Today's Appointments",
                          style: GoogleFonts.playfairDisplay(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          )),
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.webAppointments),
                        icon: const Icon(Icons.open_in_new,
                            color: AppTheme.secondary, size: 16),
                        label: Text('View All',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.secondary, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  todayApptAsync
                      .when(
                        data: (appts) {
                          final upcoming = appts
                              .where((a) =>
                                  a.status != 'cancelled' &&
                                  a.status != 'completed')
                              .take(5)
                              .toList();
                          if (upcoming.isEmpty) {
                            return _buildEmptyCard(
                                'No pending appointments today');
                          }
                          return Column(
                            children: upcoming
                                .map((a) => _ReceptionistApptTile(
                                    appointment: a, ref: ref))
                                .toList(),
                          );
                        },
                        loading: () => const LoadingWidget(),
                        error: (_, __) =>
                            _buildEmptyCard('Unable to load appointments'),
                      )
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

  Widget _buildStatsRow(
      Map<String, int> stats, AsyncValue<List<AppointmentModel>> apptAsync) {
    final total = apptAsync.value?.length ?? 0;

    return Row(
      children: [
        Expanded(
            child: _MiniStat(
                label: 'Queue',
                value: '${stats['waiting'] ?? 0}',
                icon: Icons.queue,
                color: AppTheme.warning)),
        const SizedBox(width: 10),
        Expanded(
            child: _MiniStat(
                label: 'Serving',
                value: '${stats['in_progress'] ?? 0}',
                icon: Icons.content_cut,
                color: Colors.purple)),
        const SizedBox(width: 10),
        Expanded(
            child: _MiniStat(
                label: 'Done',
                value: '${stats['completed'] ?? 0}',
                icon: Icons.check_circle,
                color: AppTheme.success)),
        const SizedBox(width: 10),
        Expanded(
            child: _MiniStat(
                label: "Today's Appts",
                value: '$total',
                icon: Icons.calendar_today,
                color: AppTheme.info)),
      ],
    );
  }

  Widget _buildQuickActions(
      BuildContext context, WidgetRef ref, String? branchId) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: [
        _QuickActionTile(
          icon: Icons.how_to_reg,
          label: 'Walk-In\nCheck-In',
          color: AppTheme.secondary,
          onTap: () => _showWalkInDialog(context, ref, branchId),
        ),
        _QuickActionTile(
          icon: Icons.calendar_today,
          label: 'Appointments',
          color: AppTheme.info,
          onTap: () => context.go(AppRoutes.webAppointments),
        ),
        _QuickActionTile(
          icon: Icons.queue,
          label: 'Manage\nQueue',
          color: AppTheme.warning,
          onTap: () => context.go(AppRoutes.webQueue),
        ),
        _QuickActionTile(
          icon: Icons.people,
          label: 'Customers',
          color: Colors.teal,
          onTap: () => context.go(AppRoutes.customers),
        ),
        _QuickActionTile(
          icon: Icons.content_cut,
          label: 'Barbers',
          color: Colors.purple,
          onTap: () => context.go(AppRoutes.barbers),
        ),
        _QuickActionTile(
          icon: Icons.calendar_month,
          label: 'Schedules',
          color: Colors.orange,
          onTap: () => context.go(AppRoutes.schedules),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Center(
        child: Text(message,
            style: GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 14)),
      ),
    );
  }

  void _showWalkInDialog(
      BuildContext context, WidgetRef ref, String? branchId) {
    showDialog(
      context: context,
      builder: (ctx) => _WalkInDialog(branchId: branchId),
    );
  }
}

// ─────────────────────────────────────────────
// Walk-In Check-In Dialog
// ─────────────────────────────────────────────
class _WalkInDialog extends ConsumerStatefulWidget {
  final String? branchId;
  const _WalkInDialog({this.branchId});

  @override
  ConsumerState<_WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends ConsumerState<_WalkInDialog> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedBarberId;
  String? _selectedServiceId;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barbersAsync  = ref.watch(allBarbersProvider);
    final servicesAsync = ref.watch(servicesProvider);

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Walk-In Check-In',
          style: GoogleFonts.playfairDisplay(color: AppTheme.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Customer Name ──────────────────────────────────────
            _DialogField(
              label: 'Customer Name',
              controller: _nameCtrl,
              hint: 'Full name',
            ),
            const SizedBox(height: 12),

            // ── Phone ──────────────────────────────────────────────
            _DialogField(
              label: 'Phone (Optional)',
              controller: _phoneCtrl,
              hint: '+63 912 ...',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // ── Service picker (required) ──────────────────────────
            Text('Service *',
                style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            servicesAsync.when(
              data: (services) => DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _selectedServiceId,
                hint: Text('Select a service',
                    style: GoogleFonts.dmSans(color: AppTheme.textHint)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
                dropdownColor: AppTheme.cardColor,
                style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
                items: services
                    .map((ServiceModel s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text('${s.name}  ·  ₱${s.price.toStringAsFixed(0)}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedServiceId = v),
              ),
              loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator()),
              error: (_, __) => Text('Could not load services',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.error, fontSize: 12)),
            ),
            const SizedBox(height: 12),

            // ── Barber picker (optional) ───────────────────────────
            Text('Select Barber (Optional)',
                style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            barbersAsync.when(
              data: (barbers) {
                final available = barbers.where((b) => b.isAvailable).toList();
                return DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _selectedBarberId,
                  hint: Text('Any available barber',
                      style: GoogleFonts.dmSans(color: AppTheme.textHint)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  dropdownColor: AppTheme.cardColor,
                  style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
                  items: available
                      .map((b) => DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(b.displayName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedBarberId = v),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.dmSans(color: AppTheme.textHint)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondary,
            foregroundColor: Colors.black,
          ),
          onPressed: _loading ? null : _handleCheckIn,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black))
              : Text('Check In',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _handleCheckIn() async {
    final name = _nameCtrl.text.trim();

    // ── Validate ───────────────────────────────────────────────────
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }
    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service')),
      );
      return;
    }
    final branchId = widget.branchId;
    if (branchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active branch found')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ── Create walk-in appointment + queue entry via repository ──
      final queueEntry = await ref
          .read(queueNotifierProvider.notifier)
          .addWalkIn(
            branchId: branchId,
            serviceId: _selectedServiceId!,
            barberId: _selectedBarberId,   // null → any available barber
            customerName: name,
          );

      if (!mounted) return;

      if (queueEntry == null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check-in failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$name checked in — Queue #${queueEntry.queueNumber}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.dmSans(
            color: AppTheme.secondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          )),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.playfairDisplay(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              )),
          Text(label,
              style: GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2A3A)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final QueueModel entry;
  const _QueueTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#${entry.queueNumber}',
                style: GoogleFonts.dmSans(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Queue #${entry.queueNumber}',
              style:
                  GoogleFonts.dmSans(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ),
          if (entry.estimatedWaitMinutes != null)
            Text(
              '~${entry.estimatedWaitMinutes} min',
              style: GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _ReceptionistApptTile extends StatelessWidget {
  final AppointmentModel appointment;
  final WidgetRef ref;

  const _ReceptionistApptTile({required this.appointment, required this.ref});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(appointment.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                appointment.appointmentTime.length >= 5
                    ? appointment.appointmentTime.substring(0, 5)
                    : appointment.appointmentTime,
                style: GoogleFonts.dmSans(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                  '${appointment.serviceName ?? 'Service'} • ${appointment.barberName ?? 'Any barber'}',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              appointment.status.replaceAll('_', ' '),
              style: GoogleFonts.dmSans(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
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
      default:
        return AppTheme.textHint;
    }
  }
}

class _DialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _DialogField({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.dmSans(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(color: AppTheme.textHint),
            filled: true,
            fillColor: AppTheme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

// Provider stubs for compilation
final activeServicesProvider = FutureProvider<List<dynamic>>((ref) async => []);