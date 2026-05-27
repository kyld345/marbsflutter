// lib/features/schedules/presentation/schedules_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/schedule_provider.dart';
import '../domain/schedule_model.dart';
import '../../barbers/domain/barber_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  String? _selectedBarberId;

  static const List<String> _daysShort = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];

  @override
  Widget build(BuildContext context) {
    final barbersAsync = ref.watch(allBarbersProvider);
    final schedulesAsync = ref.watch(schedulesProvider(_selectedBarberId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Schedules',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Barber selector
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: barbersAsync.when(
              data: (barbers) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All Barbers', null),
                    ...barbers.map((b) => _filterChip(b.displayName, b.id)),
                  ],
                ),
              ),
              loading: () => const SizedBox(height: 36),
              error: (_, __) => const SizedBox(),
            ),
          ),

          Expanded(
            child: schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_outlined,
                            size: 64, color: AppTheme.textHint),
                        const SizedBox(height: 16),
                        Text('No schedules set',
                            style: GoogleFonts.playfairDisplay(
                                color: AppTheme.textSecondary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Add schedules for barbers using the edit button',
                            style:
                                GoogleFonts.dmSans(color: AppTheme.textHint)),
                      ],
                    ),
                  );
                }

                // Group by barber
                final Map<String, List<ScheduleModel>> grouped = {};
                for (final s in schedules) {
                  grouped.putIfAbsent(s.barberId, () => []).add(s);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (_, i) {
                    final barberId = grouped.keys.elementAt(i);
                    final barberSchedules = grouped[barberId]!;
                    final barberName = barberSchedules.first.barberName;
                    return _buildBarberScheduleCard(
                      barberId: barberId,
                      barberName: barberName,
                      schedules: barberSchedules,
                      index: i,
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => AppErrorWidget(error: e.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScheduleDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Schedule'),
      ),
    );
  }

  Widget _filterChip(String label, String? barberId) {
    final isSelected = _selectedBarberId == barberId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedBarberId = barberId),
        backgroundColor: AppTheme.cardColor,
        selectedColor: AppTheme.secondary.withValues(alpha: 0.15),
        checkmarkColor: AppTheme.secondary,
        labelStyle: GoogleFonts.dmSans(
          color: isSelected ? AppTheme.secondary : AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isSelected ? AppTheme.secondary : const Color(0xFF37474F),
        ),
      ),
    );
  }

  Widget _buildBarberScheduleCard({
    required String barberId,
    required String barberName,
    required List<ScheduleModel> schedules,
    required int index,
  }) {
    // Build full week: fill missing days
    final weekMap = {
      for (final s in schedules) s.dayOfWeek: s,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                  child: Text(barberName.substring(0, 1),
                      style: GoogleFonts.dmSans(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(barberName,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined,
                      color: AppTheme.secondary, size: 20),
                  onPressed: () =>
                      _showEditScheduleDialog(context, ref, barberId, weekMap),
                  tooltip: 'Edit Schedule',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Days grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: List.generate(7, (dayIndex) {
                final schedule = weekMap[dayIndex];
                final isDayOff = schedule?.isDayOff ?? true;
                final isToday = DateTime.now().weekday % 7 == dayIndex;

                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.secondary.withValues(alpha: 0.1)
                          : isDayOff
                              ? AppTheme.surface
                              : AppTheme.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isToday
                            ? AppTheme.secondary.withValues(alpha: 0.4)
                            : isDayOff
                                ? Colors.transparent
                                : AppTheme.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _daysShort[dayIndex],
                          style: GoogleFonts.dmSans(
                            color: isToday
                                ? AppTheme.secondary
                                : isDayOff
                                    ? AppTheme.textHint
                                    : AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          isDayOff ? Icons.close : Icons.check,
                          size: 14,
                          color: isDayOff
                              ? AppTheme.textHint.withValues(alpha: 0.5)
                              : AppTheme.success,
                        ),
                        if (!isDayOff && schedule != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _shortTime(schedule.startTime),
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textHint,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            _shortTime(schedule.endTime),
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textHint,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (index * 80).ms);
  }

  String _shortTime(String time) {
    final parts = time.split(':');
    final h = int.parse(parts[0]);
    final m = parts[1];
    final period = h >= 12 ? 'p' : 'a';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m$period';
  }

  void _showEditScheduleDialog(
    BuildContext context,
    WidgetRef ref,
    String barberId,
    Map<int, ScheduleModel> weekMap,
  ) {
    final selected = Map<int, bool>.fromEntries(
      List.generate(7, (i) => MapEntry(i, !(weekMap[i]?.isDayOff ?? true))),
    );
    final startCtrl = TextEditingController(text: '08:00');
    final endCtrl = TextEditingController(text: '18:00');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Work Schedule',
              style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Working Days',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(7, (i) {
                    final isOn = selected[i] ?? false;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => selected[i] = !isOn),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                isOn ? AppTheme.secondary : AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _daysShort[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              color: isOn ? Colors.black : AppTheme.textHint,
                              fontSize: 12,
                              fontWeight:
                                  isOn ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Text('Working Hours',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: startCtrl,
                        label: 'Start Time',
                        hint: '08:00',
                        prefixIcon: Icons.schedule,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppTextField(
                        controller: endCtrl,
                        label: 'End Time',
                        hint: '18:00',
                        prefixIcon: Icons.schedule_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                for (int day = 0; day < 7; day++) {
                  await ref
                      .read(scheduleNotifierProvider.notifier)
                      .upsertSchedule(
                        barberId: barberId,
                        dayOfWeek: day,
                        startTime: startCtrl.text,
                        endTime: endCtrl.text,
                        isDayOff: !(selected[day] ?? false),
                      );
                }
                ref.invalidate(schedulesProvider(_selectedBarberId));
              },
              child: const Text('Save Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context, WidgetRef ref) {
    final barbersAsync = ref.read(allBarbersProvider);
    barbersAsync.when(
      data: (barbers) {
        if (barbers.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No barbers found. Add barbers first.')),
          );
          return;
        }
        // FIX: prefer the currently-selected barber chip, fall back to first
        final targetBarberId = _selectedBarberId ?? barbers.first.id;
        _showEditScheduleDialog(
          context,
          ref,
          targetBarberId,
          {},
        );
      },
      loading: () {},
      error: (_, __) {},
    );
  }
}
