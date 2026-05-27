// lib/features/dashboard/presentation/admin_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../appointments/domain/appointment_provider.dart';
import '../../queue/domain/queue_provider.dart';
import '../../barbers/domain/barber_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/branch_provider.dart';
import '../../../widgets/common_widgets.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(activeBranchIdProvider).value;
    final statsAsync = branchId == null
        ? const AsyncLoading<Map<String, int>>()
        : ref.watch(todayStatsProvider(branchId));
    final queueStatsAsync = ref.watch(queueStatsProvider);
    final barbersAsync = ref.watch(allBarbersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            Text(
              _getFormattedDate(),
              style: GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 12),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(todayStatsProvider);
              ref.invalidate(queueStatsProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today's appointment stats
            statsAsync
                .when(
                  data: (stats) => _buildStatsGrid(stats),
                  loading: () => const LoadingWidget(),
                  error: (_, __) => const SizedBox(),
                )
                .animate()
                .fadeIn(),

            const SizedBox(height: 24),

            // Queue stats + active barbers
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Queue overview
                Expanded(
                  flex: 2,
                  child: queueStatsAsync.when(
                    data: (stats) => _buildQueueCard(stats),
                    loading: () => const LoadingWidget(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
                const SizedBox(width: 16),

                // Barber status
                Expanded(
                  flex: 3,
                  child: barbersAsync.when(
                    data: (barbers) => _buildBarberStatus(barbers),
                    loading: () => const LoadingWidget(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 150.ms),

            const SizedBox(height: 24),

            // Revenue chart
            _buildRevenueChart().animate().fadeIn(delay: 250.ms),

            const SizedBox(height: 24),

            // Appointment status breakdown
            statsAsync
                .when(
                  data: (stats) => _buildStatusBreakdown(stats),
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                )
                .animate()
                .fadeIn(delay: 350.ms),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, int> stats) {
    final items = [
      {
        'label': 'Total Today',
        'value': stats['total'] ?? 0,
        'icon': Icons.calendar_today,
        'color': AppTheme.info,
      },
      {
        'label': 'Pending',
        'value': stats['pending'] ?? 0,
        'icon': Icons.pending_outlined,
        'color': AppTheme.statusPendingColor,
      },
      {
        'label': 'In Progress',
        'value': stats['in_progress'] ?? 0,
        'icon': Icons.content_cut,
        'color': AppTheme.statusInProgressColor,
      },
      {
        'label': 'Completed',
        'value': stats['completed'] ?? 0,
        'icon': Icons.check_circle_outline,
        'color': AppTheme.statusCompletedColor,
      },
    ];

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.asMap().entries.map((e) {
        final item = e.value;
        final color = item['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(item['icon'] as IconData, color: color, size: 18),
                  ),
                  const Icon(Icons.arrow_upward,
                      size: 14, color: AppTheme.success),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['value']}',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQueueCard(Map<String, int> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Queue Status',
              style: GoogleFonts.dmSans(
                color: AppTheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 16),
          _queueStat(
              'Waiting', stats['waiting'] ?? 0, AppTheme.statusPendingColor),
          const SizedBox(height: 12),
          _queueStat('Serving', stats['in_progress'] ?? 0,
              AppTheme.statusInProgressColor),
          const SizedBox(height: 12),
          _queueStat(
              'Done', stats['completed'] ?? 0, AppTheme.statusCompletedColor),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: GoogleFonts.dmSans(color: AppTheme.textSecondary)),
              Text('${stats['total'] ?? 0}',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _queueStat(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
        Text('$value',
            style: GoogleFonts.dmSans(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            )),
      ],
    );
  }

  Widget _buildBarberStatus(List barbers) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Barber Status',
              style: GoogleFonts.dmSans(
                color: AppTheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 16),
          ...barbers.take(5).map((b) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                    child: Text(
                      b.displayName.substring(0, 1),
                      style: GoogleFonts.dmSans(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.displayName,
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            )),
                        Text(b.specialization ?? 'General',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textHint, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: b.isAvailable
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.textHint.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      b.isAvailable ? 'Available' : 'Busy',
                      style: GoogleFonts.dmSans(
                        color: b.isAvailable
                            ? AppTheme.success
                            : AppTheme.textHint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    // Sample data - in production, fetch from Supabase
    final spots = [
      const FlSpot(0, 1200),
      const FlSpot(1, 1800),
      const FlSpot(2, 1400),
      const FlSpot(3, 2200),
      const FlSpot(4, 1900),
      const FlSpot(5, 2500),
      const FlSpot(6, 2100),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Revenue (7 days)',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  )),
              Text('₱15,100',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.cardColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (v, _) => Text(
                        '₱${(v / 1000).toStringAsFixed(0)}k',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textHint, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        return Text(days[v.toInt()],
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textHint, fontSize: 10));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.secondary,
                    barWidth: 2.5,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.secondary.withValues(alpha: 0.3),
                          AppTheme.secondary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(Map<String, int> stats) {
    final total = (stats['total'] ?? 1).clamp(1, 99999);
    final items = [
      {
        'label': 'Completed',
        'value': stats['completed'] ?? 0,
        'color': AppTheme.statusCompletedColor
      },
      {
        'label': 'Pending',
        'value': stats['pending'] ?? 0,
        'color': AppTheme.statusPendingColor
      },
      {
        'label': 'Confirmed',
        'value': stats['confirmed'] ?? 0,
        'color': AppTheme.statusConfirmedColor
      },
      {
        'label': 'Cancelled',
        'value': stats['cancelled'] ?? 0,
        'color': AppTheme.statusCancelledColor
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Breakdown',
              style: GoogleFonts.dmSans(
                color: AppTheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 16),
          ...items.map((item) {
            final pct =
                ((item['value'] as int) / total * 100).clamp(0.0, 100.0);
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['label'] as String,
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      Text('${item['value']} (${pct.toStringAsFixed(0)}%)',
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textHint, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: AppTheme.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}
