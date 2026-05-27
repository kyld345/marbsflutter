// lib/features/reports/presentation/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

// Report data provider
final reportDataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, period) async {
  final client = ref.watch(supabaseClientProvider);

  DateTime from;
  final now = DateTime.now();

  switch (period) {
    case 'week':
      from = now.subtract(const Duration(days: 7));
      break;
    case 'month':
      from = DateTime(now.year, now.month, 1);
      break;
    case 'year':
      from = DateTime(now.year, 1, 1);
      break;
    default:
      from = now.subtract(const Duration(days: 7));
  }

  final fromStr = from.toIso8601String();

  final appointments = await client
      .from(SupabaseConfig.appointmentsTable)
      .select('status, total_price, created_at, services(name)')
      .gte('created_at', fromStr)
      .order('created_at');

  final totalRevenue = appointments
      .where((a) => a['status'] == 'completed')
      .fold<double>(
          0, (sum, a) => sum + ((a['total_price'] as num?)?.toDouble() ?? 0));

  final statusCounts = <String, int>{};
  for (final a in appointments) {
    final s = a['status'] as String;
    statusCounts[s] = (statusCounts[s] ?? 0) + 1;
  }

  // Service popularity
  final serviceCounts = <String, int>{};
  for (final a in appointments) {
    final svc = (a['services'] as Map<String, dynamic>?)?['name'] as String? ??
        'Unknown';
    serviceCounts[svc] = (serviceCounts[svc] ?? 0) + 1;
  }

  // Daily revenue for chart
  final dailyRevenue = <String, double>{};
  for (final a in appointments) {
    if (a['status'] != 'completed') continue;
    final date = a['created_at'].toString().substring(0, 10);
    dailyRevenue[date] = (dailyRevenue[date] ?? 0) +
        ((a['total_price'] as num?)?.toDouble() ?? 0);
  }

  return {
    'total': appointments.length,
    'revenue': totalRevenue,
    'statusCounts': statusCounts,
    'serviceCounts': serviceCounts,
    'dailyRevenue': dailyRevenue,
  };
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDataProvider(_period));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Reports',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'week', label: Text('Week')),
              ButtonSegment(value: 'month', label: Text('Month')),
              ButtonSegment(value: 'year', label: Text('Year')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: reportAsync.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKpiRow(data).animate().fadeIn(),
              const SizedBox(height: 20),
              _buildRevenueChart(data).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        _buildStatusPie(data).animate().fadeIn(delay: 200.ms),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child:
                        _buildTopServices(data).animate().fadeIn(delay: 250.ms),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(error: e.toString()),
      ),
    );
  }

  Widget _buildKpiRow(Map<String, dynamic> data) {
    final revenue = data['revenue'] as double;
    final total = data['total'] as int;
    final completed =
        (data['statusCounts'] as Map<String, int>)['completed'] ?? 0;
    final rate = total > 0 ? (completed / total * 100).toStringAsFixed(0) : '0';

    final kpis = [
      {
        'label': 'Total Appointments',
        'value': '$total',
        'icon': Icons.calendar_today,
        'color': AppTheme.info
      },
      {
        'label': 'Completed',
        'value': '$completed',
        'icon': Icons.check_circle_outline,
        'color': AppTheme.success
      },
      {
        'label': 'Revenue',
        'value': '₱${_formatRevenue(revenue)}',
        'icon': Icons.payments_outlined,
        'color': AppTheme.secondary
      },
      {
        'label': 'Completion Rate',
        'value': '$rate%',
        'icon': Icons.trending_up,
        'color': AppTheme.statusInProgressColor
      },
    ];

    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: kpis.map((kpi) {
        final color = kpi['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(kpi['icon'] as IconData, color: color, size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kpi['value'] as String,
                      style: GoogleFonts.dmSans(
                        color: color,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      )),
                  Text(kpi['label'] as String,
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRevenueChart(Map<String, dynamic> data) {
    final dailyRevenue = data['dailyRevenue'] as Map<String, double>;
    final entries = dailyRevenue.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('No revenue data for this period',
              style: GoogleFonts.dmSans(color: AppTheme.textHint)),
        ),
      );
    }

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

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
              Text('Revenue Trend',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  )),
              Text(
                '₱${_formatRevenue(data['revenue'] as double)} total',
                style: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFF1E2A3A),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) => Text(
                        '₱${_formatRevenue(v)}',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textHint, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: entries.length > 7 ? 2 : 1,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= 0 && idx < entries.length) {
                          final date = entries[idx].key;
                          return Text(date.substring(5),
                              style: GoogleFonts.dmSans(
                                  color: AppTheme.textHint, fontSize: 10));
                        }
                        return const SizedBox();
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
                          AppTheme.secondary.withValues(alpha: 0.25),
                          AppTheme.secondary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(
                      show: spots.length < 15,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: AppTheme.secondary,
                        strokeColor: AppTheme.background,
                        strokeWidth: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPie(Map<String, dynamic> data) {
    final counts = data['statusCounts'] as Map<String, int>;
    final total = counts.values.fold(0, (a, b) => a + b);

    final items = [
      {
        'label': 'Completed',
        'key': 'completed',
        'color': AppTheme.statusCompletedColor
      },
      {
        'label': 'Pending',
        'key': 'pending',
        'color': AppTheme.statusPendingColor
      },
      {
        'label': 'Confirmed',
        'key': 'confirmed',
        'color': AppTheme.statusConfirmedColor
      },
      {
        'label': 'Cancelled',
        'key': 'cancelled',
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
          Text('Status Distribution',
              style: GoogleFonts.dmSans(
                color: AppTheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: total == 0
                ? Center(
                    child: Text('No data',
                        style: GoogleFonts.dmSans(color: AppTheme.textHint)))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: items.map((item) {
                        final count = counts[item['key'] as String] ?? 0;
                        final pct = total > 0 ? count / total : 0.0;
                        return PieChartSectionData(
                          value: pct * 100,
                          color: item['color'] as Color,
                          radius: 50,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final count = counts[item['key'] as String] ?? 0;
            final pct =
                total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
            final color = item['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item['label'] as String,
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  Text('$count ($pct%)',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopServices(Map<String, dynamic> data) {
    final serviceCounts = data['serviceCounts'] as Map<String, int>;
    final sorted = serviceCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final maxCount = top.isEmpty ? 1 : top.first.value;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Services',
              style: GoogleFonts.dmSans(
                color: AppTheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              )),
          const SizedBox(height: 16),
          if (top.isEmpty)
            Center(
              child: Text('No data',
                  style: GoogleFonts.dmSans(color: AppTheme.textHint)),
            )
          else
            ...top.asMap().entries.map((e) {
              final idx = e.key;
              final entry = e.value;
              final pct = entry.value / maxCount;
              final colors = [
                AppTheme.secondary,
                AppTheme.info,
                AppTheme.success,
                AppTheme.statusInProgressColor,
                AppTheme.warning,
                AppTheme.textHint,
              ];
              final color = colors[idx % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value}',
                          style: GoogleFonts.dmSans(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: AppTheme.surface,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
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

  String _formatRevenue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toStringAsFixed(0);
  }
}
