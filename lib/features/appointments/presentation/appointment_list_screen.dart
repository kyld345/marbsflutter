// lib/features/appointments/presentation/appointment_list_screen.dart
// FIXED: unified screen for customer (mobile), admin/receptionist (web), barber (web)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../domain/appointment_provider.dart';
import '../domain/appointment_model.dart';
import '../../auth/domain/auth_provider.dart';
import '../../barbers/domain/barber_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../routes/app_router.dart';
import '../../../widgets/common_widgets.dart';

class AppointmentListScreen extends ConsumerStatefulWidget {
  final bool isWebView;
  final bool barberView;

  const AppointmentListScreen({
    super.key,
    this.isWebView = false,
    this.barberView = false,
  });

  @override
  ConsumerState<AppointmentListScreen> createState() =>
      _AppointmentListScreenState();
}

class _AppointmentListScreenState
    extends ConsumerState<AppointmentListScreen> {
  String? _statusFilter;
  DateTime? _dateFilter;
  int _currentPage = 0;

  final List<String?> _statusOptions = [
    null, 'pending', 'confirmed', 'in_progress', 'completed', 'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final authUser = ref.watch(authStateProvider).value;

    if (!widget.isWebView) {
      // Customer mobile view
      return _buildCustomerView(role);
    }

    // Staff/barber web view
    return _buildStaffView(role, authUser?.id);
  }

  // ── Customer mobile view ─────────────────────────────────
  Widget _buildCustomerView(String role) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('My Appointments',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
            labelStyle: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle:
                GoogleFonts.dmSans(fontSize: 13),
          ),
        ),
      body: const TabBarView(
          children: [
            _CustomerAppointmentTab(statusFilter: 'upcoming'),
            _CustomerAppointmentTab(statusFilter: 'completed'),
            _CustomerAppointmentTab(statusFilter: 'cancelled'),
          ],
        ),
      ),
    );
  }

  // ── Staff/barber web view ────────────────────────────────
  Widget _buildStaffView(String role, String? userId) {
    String? barberIdFilter;

    // If barber view, we MUST have the barber record before fetching
    // appointments, otherwise we'd first fetch with barberId=null (all
    // appointments), then refetch once barbers load — causing a visible
    // double-loading flicker.
    if (widget.barberView) {
      final barbersAsync = ref.watch(allBarbersProvider);

      // Still loading → show spinner; don't touch allAppointmentsProvider yet.
      if (barbersAsync.isLoading) return const LoadingWidget();

      // Failed to load barbers → surface the error.
      if (barbersAsync.hasError) {
        return AppErrorWidget(
          error: barbersAsync.error.toString(),
          onRetry: () => ref.invalidate(allBarbersProvider),
        );
      }

      final myBarber = barbersAsync.value?.firstWhere(
        (b) => b.userId == userId,
        orElse: () => barbersAsync.value!.first,
      );
      barberIdFilter = myBarber?.id;
    }

    final filter = AppointmentFilter(
      status: _statusFilter,
      date: _dateFilter,
      barberId: barberIdFilter,
      page: _currentPage,
    );
    final appointmentsAsync = ref.watch(allAppointmentsProvider(filter));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.barberView ? 'My Appointments' : 'Appointments',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text('Manage and update appointment statuses',
                style: GoogleFonts.dmSans(
                    color: AppTheme.textHint, fontSize: 12)),
          ],
        ),
        actions: [
          // Date filter
          TextButton.icon(
            onPressed: () => _pickDate(context),
            icon: Icon(
              _dateFilter != null ? Icons.calendar_today : Icons.calendar_today_outlined,
              color: _dateFilter != null ? AppTheme.secondary : AppTheme.textHint,
              size: 18,
            ),
            label: Text(
              _dateFilter != null
                  ? DateFormat('MMM d').format(_dateFilter!)
                  : 'All Dates',
              style: GoogleFonts.dmSans(
                color: _dateFilter != null
                    ? AppTheme.secondary
                    : AppTheme.textHint,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Status filter
          _StatusFilterChip(
            selected: _statusFilter,
            options: _statusOptions,
            onChanged: (v) => setState(() {
              _statusFilter = v;
              _currentPage = 0;
            }),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allAppointmentsProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: appointmentsAsync.when(
        data: (appointments) {
          if (appointments.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_today_outlined,
              title: 'No Appointments Found',
              subtitle: _statusFilter != null
                  ? 'No ${_statusFilter!.replaceAll('_', ' ')} appointments'
                  : 'No appointments match your filters',
              actionLabel: _statusFilter != null || _dateFilter != null
                  ? 'Clear Filters'
                  : null,
              onAction: () => setState(() {
                _statusFilter = null;
                _dateFilter = null;
              }),
            );
          }

          return Column(
            children: [
              // Count bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                color: AppTheme.surface,
                child: Row(
                  children: [
                    Text(
                      '${appointments.length} appointment${appointments.length == 1 ? '' : 's'}',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 13),
                    ),
                    const Spacer(),
                    if (_statusFilter != null || _dateFilter != null)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _statusFilter = null;
                          _dateFilter = null;
                        }),
                        icon: const Icon(Icons.clear, size: 14),
                        label: Text('Clear filters',
                            style: GoogleFonts.dmSans(fontSize: 12)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textHint),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: appointments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _StaffAppointmentTile(
                    appointment: appointments[i],
                    canEdit: role == AppConstants.roleAdmin ||
                        role == AppConstants.roleReceptionist ||
                        widget.barberView,
                    barberView: widget.barberView,
                  ).animate().fadeIn(
                      delay: Duration(milliseconds: i * 30),
                      duration: 250.ms),
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          error: e.toString(),
          onRetry: () => ref.invalidate(allAppointmentsProvider),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppTheme.secondary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateFilter = picked;
        _currentPage = 0;
      });
    }
  }

}

// ── Customer tab ──────────────────────────────────────────
class _CustomerAppointmentTab extends ConsumerWidget {
  final String statusFilter;
  const _CustomerAppointmentTab({required this.statusFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? status;
    if (statusFilter == 'upcoming') {
      status = null; // we filter client-side
    } else if (statusFilter == 'completed') {
      status = 'completed';
    } else {
      status = 'cancelled';
    }

    final appointmentsAsync = ref.watch(customerAppointmentsProvider(status));

    return appointmentsAsync.when(
      data: (appointments) {
        final filtered = statusFilter == 'upcoming'
            ? appointments
                .where((a) =>
                    a.status != 'completed' && a.status != 'cancelled')
                .toList()
            : appointments;

        if (filtered.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_today_outlined,
            title: 'No ${statusFilter.capitalize()} Appointments',
            subtitle: statusFilter == 'upcoming'
                ? 'Book your first appointment now!'
                : null,
            actionLabel:
                statusFilter == 'upcoming' ? 'Book Now' : null,
            onAction: statusFilter == 'upcoming'
                ? () => context.go(AppRoutes.bookAppointment)
                : null,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _CustomerAppointmentCard(
            appointment: filtered[i],
          ).animate().fadeIn(
              delay: Duration(milliseconds: i * 50),
              duration: 300.ms),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(error: e.toString()),
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}

// ── Customer card ─────────────────────────────────────────
class _CustomerAppointmentCard extends ConsumerWidget {
  final AppointmentModel appointment;
  const _CustomerAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = AppTheme.getStatusColor(appointment.status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.content_cut,
                      color: statusColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.serviceName ?? 'Haircut Service',
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        appointment.barberName ?? 'Any available barber',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textHint, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: appointment.status),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: DateFormat('MMM d, y')
                      .format(appointment.appointmentDate),
                ),
                const SizedBox(width: 10),
                _InfoChip(
                  icon: Icons.access_time,
                  label: appointment.formattedTime,
                ),
                if (appointment.totalPrice != null) ...[
                  const SizedBox(width: 10),
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: '₱${appointment.totalPrice!.toStringAsFixed(0)}',
                  ),
                ],
              ],
            ),
          ),

          // Actions
          if (appointment.canCancel || appointment.canReview)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (appointment.canCancel)
                    OutlinedButton(
                      onPressed: () => _cancelAppointment(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.dmSans(fontSize: 12)),
                    ),
                  if (appointment.canReview) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          context.go('${AppRoutes.reviews}?appointmentId=${appointment.id}'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Leave Review',
                          style: GoogleFonts.dmSans(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _cancelAppointment(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel Appointment',
      message:
          'Are you sure you want to cancel this appointment? This cannot be undone.',
      confirmText: 'Cancel Appointment',
      isDanger: true,
    );
    if (!confirmed) return;
    final success = await ref
        .read(appointmentNotifierProvider.notifier)
        .cancelAppointment(appointment.id);
    if (success) {
      ref.invalidate(customerAppointmentsProvider);
    }
  }
}

// ── Staff appointment tile ────────────────────────────────
class _StaffAppointmentTile extends ConsumerWidget {
  final AppointmentModel appointment;
  final bool canEdit;
  final bool barberView;

  const _StaffAppointmentTile({
    required this.appointment,
    this.canEdit = false,
    this.barberView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = AppTheme.getStatusColor(appointment.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Time block
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    appointment.formattedTime,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appointment.customerName ?? 'Customer',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        StatusBadge(status: appointment.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${appointment.serviceName ?? 'Service'} • ${appointment.barberName ?? 'Any barber'}',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppTheme.textHint, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y')
                              .format(appointment.appointmentDate),
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textHint, fontSize: 12),
                        ),
                        if (appointment.totalPrice != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.payments_outlined,
                              color: AppTheme.textHint, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '₱${appointment.totalPrice!.toStringAsFixed(0)}',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textHint, fontSize: 12),
                          ),
                        ],
                        if (appointment.isWalkIn) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('WALK-IN',
                                style: GoogleFonts.dmSans(
                                  color: AppTheme.info,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Admin/receptionist 3-dot menu
              if (canEdit && !barberView)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppTheme.textHint, size: 20),
                  color: AppTheme.cardColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) =>
                      _handleAction(action, context, ref),
                  itemBuilder: (ctx) => _buildAdminMenuItems(),
                ),
            ],
          ),

          // ── Barber Accept / Reject row (pending only) ──────────
          if (barberView && appointment.status == 'pending') ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1E2A3A), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _handleAction('cancelled', context, ref),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text('Reject',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _handleAction('confirmed', context, ref),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('Accept',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ── Barber progress actions (confirmed / in_progress) ──
          if (barberView && appointment.status == 'confirmed') ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1E2A3A), height: 1),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _handleAction('in_progress', context, ref),
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: Text('Start Service',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],

          if (barberView && appointment.status == 'in_progress') ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1E2A3A), height: 1),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _handleAction('completed', context, ref),
                icon: const Icon(Icons.done_all, size: 16),
                label: Text('Mark as Completed',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<PopupMenuItem<String>> _buildAdminMenuItems() {
    final items = <PopupMenuItem<String>>[];

    if (appointment.status == 'pending') {
      items.add(_menuItem('confirmed', Icons.check_circle, 'Confirm', AppTheme.success));
    }
    if (appointment.status == 'confirmed') {
      items.add(_menuItem('in_progress', Icons.play_circle, 'Start Service', Colors.purple));
    }
    if (appointment.status == 'in_progress') {
      items.add(_menuItem('completed', Icons.done_all, 'Mark Complete', AppTheme.success));
    }
    if (appointment.status != 'cancelled' &&
        appointment.status != 'completed') {
      items.add(_menuItem('no_show', Icons.person_off, 'No Show', AppTheme.warning));
      items.add(_menuItem('cancelled', Icons.cancel, 'Cancel', AppTheme.error));
    }

    return items;
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _handleAction(
      String action, BuildContext context, WidgetRef ref) async {
    if (action == 'cancelled') {
      final confirmed = await showConfirmDialog(
        context,
        title: barberView ? 'Reject Appointment' : 'Cancel Appointment',
        message: barberView
            ? 'Reject this appointment request from the customer?'
            : 'Cancel this appointment?',
        isDanger: true,
        confirmText: barberView ? 'Reject' : 'Cancel Appointment',
      );
      if (!confirmed) return;
    }

    final success = await ref
        .read(appointmentNotifierProvider.notifier)
        .updateStatus(appointment.id, action);

    if (success) {
      ref.invalidate(allAppointmentsProvider);
    }
  }
}

// ── Status filter chip ────────────────────────────────────
class _StatusFilterChip extends StatelessWidget {
  final String? selected;
  final List<String?> options;
  final void Function(String?) onChanged;

  const _StatusFilterChip({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onChanged,
      itemBuilder: (ctx) => options
          .map((s) => PopupMenuItem<String?>(
                value: s,
                child: Row(
                  children: [
                    Icon(
                      s == null ? Icons.all_inclusive : Icons.circle,
                      size: 8,
                      color: s == null
                          ? AppTheme.textHint
                          : AppTheme.getStatusColor(s),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      s == null ? 'All Statuses' : _label(s),
                      style: GoogleFonts.dmSans(
                        color: selected == s
                            ? AppTheme.secondary
                            : AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: selected == s
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected != null
                ? AppTheme.secondary.withValues(alpha: 0.5)
                : const Color(0xFF37474F),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list,
                color: selected != null
                    ? AppTheme.secondary
                    : AppTheme.textHint,
                size: 16),
            const SizedBox(width: 6),
            Text(
              selected == null ? 'Status' : _label(selected!),
              style: GoogleFonts.dmSans(
                color: selected != null
                    ? AppTheme.secondary
                    : AppTheme.textHint,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String s) =>
      s.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
}

// ── Small info chip ───────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textHint, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.dmSans(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}