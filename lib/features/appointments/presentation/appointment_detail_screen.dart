// lib/features/appointments/presentation/appointment_detail_screen.dart
// Unchanged from original — correct implementation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/appointment_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/common_widgets.dart';
import '../../auth/domain/auth_provider.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  final String appointmentId;
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(appointmentDetailProvider(appointmentId));
    final role = ref.watch(userRoleProvider);
    final isStaff = role != AppConstants.roleCustomer;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Appointment Details',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
      ),
      body: appointmentAsync.when(
        data: (apt) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.getStatusColor(apt.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.getStatusColor(apt.status).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Icon(_getStatusIcon(apt.status), color: AppTheme.getStatusColor(apt.status), size: 48),
                    const SizedBox(height: 12),
                    Text(apt.status.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.dmSans(
                          color: AppTheme.getStatusColor(apt.status),
                          fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text('${apt.formattedDate} at ${apt.formattedTime}',
                        style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
              const SizedBox(height: 20),
              _sectionCard(title: 'Service Details', icon: Icons.content_cut, children: [
                _detailRow('Service', apt.serviceName ?? 'N/A'),
                _detailRow('Duration', '${apt.serviceDuration ?? 30} min'),
                _detailRow('Price', '₱${apt.totalPrice?.toStringAsFixed(0) ?? 'N/A'}'),
                _detailRow('Payment', apt.paymentStatus.toUpperCase()),
              ]).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 16),
              _sectionCard(title: 'Barber', icon: Icons.person, children: [
                _detailRow('Name', apt.barberName ?? 'Any available barber'),
              ]).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 16),
              _sectionCard(title: 'Branch', icon: Icons.store, children: [
                _detailRow('Branch', apt.branchName ?? 'Main Branch'),
              ]).animate().fadeIn(delay: 200.ms),
              if (apt.notes != null && apt.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionCard(title: 'Notes', icon: Icons.note, children: [
                  Text(apt.notes!,
                      style: GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 14)),
                ]).animate().fadeIn(delay: 250.ms),
              ],
              const SizedBox(height: 24),
              if (apt.status == 'pending')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelAppointment(context, ref),
                    icon: const Icon(Icons.cancel_outlined, color: AppTheme.error),
                    label: Text('Cancel Appointment', style: GoogleFonts.dmSans(color: AppTheme.error)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ).animate().fadeIn(delay: 300.ms),
              if (isStaff) ...[
                const SizedBox(height: 12),
                if (apt.status == 'confirmed')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(context, ref, 'in_progress'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Service'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.info,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ).animate().fadeIn(delay: 320.ms),
                if (apt.status == 'in_progress')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(context, ref, 'completed'),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark Completed'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ).animate().fadeIn(delay: 320.ms),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(error: e.toString()),
      ),
    );
  }

  Widget _sectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppTheme.secondary, size: 18),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.dmSans(color: AppTheme.secondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1)),
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 13))),
        Expanded(child: Text(value, style: GoogleFonts.dmSans(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.pending_outlined;
      case 'confirmed': return Icons.check_circle_outline;
      case 'in_progress': return Icons.content_cut;
      case 'completed': return Icons.task_alt;
      case 'cancelled': return Icons.cancel_outlined;
      default: return Icons.info_outline;
    }
  }

  void _cancelAppointment(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Appointment', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to cancel this appointment?',
            style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No, Keep It')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(appointmentNotifierProvider.notifier).cancelAppointment(appointmentId);
              ref.invalidate(appointmentDetailProvider(appointmentId));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _updateStatus(BuildContext context, WidgetRef ref, String status) async {
    await ref.read(appointmentNotifierProvider.notifier).updateStatus(appointmentId, status);
    ref.invalidate(appointmentDetailProvider(appointmentId));
  }
}
