// lib/features/queue/presentation/queue_screen.dart
// Unified queue screen: customers see their position, staff manage the full queue

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../domain/queue_provider.dart';
import '../domain/queue_model.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

class QueueScreen extends ConsumerWidget {
  final bool isWebView;
  final bool barberView;

  const QueueScreen({
    super.key,
    this.isWebView = false,
    this.barberView = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final queueAsync = ref.watch(todayQueueProvider);
    final statsAsync = ref.watch(queueStatsProvider);

    final isStaff = role == AppConstants.roleAdmin ||
        role == AppConstants.roleReceptionist ||
        role == AppConstants.roleBarber;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: !isWebView,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Queue',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text(
              DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: GoogleFonts.dmSans(
                  color: AppTheme.textHint, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (isStaff)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(todayQueueProvider);
                ref.invalidate(queueStatsProvider);
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: queueAsync.when(
        data: (queue) {
          return CustomScrollView(
            slivers: [
              // Stats row
              SliverToBoxAdapter(
                child: statsAsync.when(
                  data: (stats) => _buildStatsRow(stats),
                  loading: () => const SizedBox(height: 80, child: LoadingWidget()),
                  error: (_, __) => const SizedBox(),
                ).animate().fadeIn(),
              ),

              // Queue list
              if (queue.isEmpty)
                const SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.queue_outlined,
                    title: 'Queue is Empty',
                    subtitle: 'No customers in queue right now.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final entry = queue[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: isStaff
                              ? _StaffQueueCard(
                                  entry: entry,
                                  position: i + 1,
                                  canManage: role != AppConstants.roleBarber ||
                                      barberView,
                                )
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: i * 40),
                                    duration: 300.ms)
                              : _CustomerQueueCard(entry: entry)
                                  .animate()
                                  .fadeIn(
                                    delay: Duration(milliseconds: i * 40),
                                    duration: 300.ms),
                        );
                      },
                      childCount: queue.length,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          error: e.toString(),
          onRetry: () => ref.invalidate(todayQueueProvider),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
              child: _StatTile(
            label: 'Waiting',
            value: '${stats['waiting'] ?? 0}',
            color: AppTheme.warning,
            icon: Icons.hourglass_empty,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _StatTile(
            label: 'In Service',
            value: '${stats['in_progress'] ?? 0}',
            color: Colors.purple,
            icon: Icons.content_cut,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _StatTile(
            label: 'Done',
            value: '${stats['completed'] ?? 0}',
            color: AppTheme.success,
            icon: Icons.check_circle,
          )),
          const SizedBox(width: 8),
          Expanded(
              child: _StatTile(
            label: 'Total',
            value:
                '${(stats['waiting'] ?? 0) + (stats['in_progress'] ?? 0) + (stats['completed'] ?? 0)}',
            color: AppTheme.info,
            icon: Icons.people,
          )),
        ],
      ),
    );
  }
}

// ── Staff queue card ──────────────────────────────────────
class _StaffQueueCard extends ConsumerWidget {
  final QueueModel entry;
  final int position;
  final bool canManage;

  const _StaffQueueCard({
    required this.entry,
    required this.position,
    this.canManage = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = AppTheme.getQueueStatusColor(entry.status);
    final isWaiting = entry.status == 'waiting';
    final isInProgress = entry.status == 'in_progress';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInProgress
              ? Colors.purple.withValues(alpha: 0.4)
              : const Color(0xFF1E2A3A),
          width: isInProgress ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Queue number
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '#${entry.queueNumber}',
                    style: GoogleFonts.playfairDisplay(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.customerName,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    StatusBadge(status: entry.status, isQueue: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.serviceName} • ${entry.barberName}',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.textHint, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        color: AppTheme.textHint, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      entry.checkInTime != null
                          ? 'Checked in ${DateFormat('h:mm a').format(entry.checkInTime!)}'
                          : 'Waiting',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 11),
                    ),
                    if (entry.estimatedWaitMinutes != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '~${entry.estimatedWaitMinutes}m wait',
                        style: GoogleFonts.dmSans(
                          color: AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions
          if (canManage)
            Column(
              children: [
                if (isWaiting)
                  _ActionBtn(
                    icon: Icons.play_circle,
                    label: 'Call',
                    color: Colors.purple,
                    onTap: () => _updateStatus(context, ref, 'in_progress'),
                  ),
                if (isInProgress)
                  _ActionBtn(
                    icon: Icons.done_all,
                    label: 'Done',
                    color: AppTheme.success,
                    onTap: () => _updateStatus(context, ref, 'completed'),
                  ),
                const SizedBox(height: 4),
                if (entry.status != 'completed' &&
                    entry.status != 'cancelled')
                  _ActionBtn(
                    icon: Icons.skip_next,
                    label: 'Skip',
                    color: AppTheme.textHint,
                    onTap: () => _updateStatus(context, ref, 'skipped'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      BuildContext context, WidgetRef ref, String newStatus) async {
    await ref.read(queueNotifierProvider.notifier).updateStatus(entry.id, newStatus);
    ref.invalidate(todayQueueProvider);
    ref.invalidate(queueStatsProvider);
  }
}

// ── Customer queue card ───────────────────────────────────
class _CustomerQueueCard extends StatelessWidget {
  final QueueModel entry;
  const _CustomerQueueCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.getQueueStatusColor(entry.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.1),
            AppTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            'Queue #${entry.queueNumber}',
            style: GoogleFonts.playfairDisplay(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          StatusBadge(status: entry.status, isQueue: true),
          const SizedBox(height: 16),
          _InfoRow(label: 'Service', value: entry.serviceName),
          const SizedBox(height: 8),
          _InfoRow(label: 'Barber', value: entry.barberName),
          if (entry.estimatedWaitMinutes != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Est. Wait',
              value: '~${entry.estimatedWaitMinutes} min',
              valueColor: AppTheme.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                color: AppTheme.textHint, fontSize: 13)),
        Text(value,
            style: GoogleFonts.dmSans(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
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
                color: AppTheme.textHint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Small action button ───────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}