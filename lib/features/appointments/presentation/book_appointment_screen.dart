// lib/features/appointments/presentation/book_appointment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../domain/appointment_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../../services/domain/service_provider.dart';
import '../../barbers/domain/barber_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/branch_provider.dart';
import '../../../widgets/common_widgets.dart';
import '../../../routes/app_router.dart';

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  int _step = 0; // 0: Service, 1: Barber, 2: Date/Time, 3: Confirm
  String? _selectedServiceId;
  String? _selectedBarberId;
  String? _selectedBarberName; // FIX: store name so confirm step can show it
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTime;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  final List<String> _timeSlots = [
    '08:00',
    '08:30',
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00',
    '18:30',
    '19:00',
    '19:30',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Book Appointment',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed:
              _step == 0 ? () => context.pop() : () => setState(() => _step--),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStep(),
            ),
          ),
          if (_step < 3) _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Service', 'Barber', 'Schedule', 'Confirm'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: AppTheme.surface,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _step;
          final isDone = index < _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppTheme.success
                              : isActive
                                  ? AppTheme.secondary
                                  : AppTheme.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? AppTheme.secondary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : Text(
                                  '${index + 1}',
                                  style: GoogleFonts.dmSans(
                                    color: isActive
                                        ? Colors.black
                                        : AppTheme.textHint,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[index],
                        style: GoogleFonts.dmSans(
                          color:
                              isActive ? AppTheme.secondary : AppTheme.textHint,
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.only(bottom: 20),
                      color: isDone ? AppTheme.success : AppTheme.cardColor,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _buildServiceStep();
      case 1:
        return _buildBarberStep();
      case 2:
        return _buildScheduleStep();
      case 3:
        return _buildConfirmStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildServiceStep() {
    final servicesAsync = ref.watch(servicesProvider);
    return servicesAsync.when(
      data: (services) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: services.length,
        itemBuilder: (_, index) {
          final service = services[index];
          final isSelected = _selectedServiceId == service.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _selectedServiceId = service.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.secondary.withValues(alpha: 0.1)
                      : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.secondary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.content_cut,
                        color:
                            isSelected ? AppTheme.secondary : AppTheme.textHint,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.description ?? '',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 14, color: AppTheme.textHint),
                              const SizedBox(width: 4),
                              Text(
                                '${service.durationMinutes} min',
                                style: GoogleFonts.dmSans(
                                  color: AppTheme.textHint,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${service.price.toStringAsFixed(0)}',
                          style: GoogleFonts.dmSans(
                            color: AppTheme.secondary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: AppTheme.secondary, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1);
        },
      ),
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(error: e.toString()),
    );
  }

  Widget _buildBarberStep() {
    final barbersAsync = ref.watch(barbersProvider);
    return barbersAsync.when(
      data: (barbers) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // "Any barber" option
          _buildBarberTile(
            id: null,
            name: 'Any Available Barber',
            specialization: 'We\'ll assign the next available barber',
            rating: 0,
            isAny: true,
          ),
          const SizedBox(height: 12),
          ...barbers.asMap().entries.map((e) => _buildBarberTile(
                id: e.value.id,
                name: e.value.displayName,
                specialization: e.value.specialization ?? 'General Barber',
                rating: e.value.rating,
                avatarUrl: e.value.avatarUrl,
              ).animate().fadeIn(delay: (e.key * 50).ms)),
        ],
      ),
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(error: e.toString()),
    );
  }

  Widget _buildBarberTile({
    required String? id,
    required String name,
    required String specialization,
    required double rating,
    String? avatarUrl,
    bool isAny = false,
  }) {
    final isSelected = _selectedBarberId == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() {
              _selectedBarberId = id;
              _selectedBarberName = isAny ? null : name;
            }),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.secondary.withValues(alpha: 0.1)
                : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.secondary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
                child: isAny
                    ? const Icon(Icons.shuffle, color: AppTheme.secondary)
                    : (avatarUrl != null
                        ? null
                        : Text(
                            name.substring(0, 1).toUpperCase(),
                            style: GoogleFonts.dmSans(
                              color: AppTheme.secondary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        )),
                    Text(specialization,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        )),
                    if (!isAny && rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppTheme.secondary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.dmSans(
                              color: AppTheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppTheme.secondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date',
            style: GoogleFonts.dmSans(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 90)),
              focusedDay: _selectedDate,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDate),
              onDaySelected: (selected, focused) {
                setState(() => _selectedDate = selected);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.secondary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                weekendTextStyle:
                    const TextStyle(color: AppTheme.textSecondary),
                defaultTextStyle: const TextStyle(color: AppTheme.textPrimary),
                outsideTextStyle: const TextStyle(color: AppTheme.textHint),
                selectedTextStyle: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w700),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: GoogleFonts.dmSans(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: const Icon(Icons.chevron_left,
                    color: AppTheme.textSecondary),
                rightChevronIcon: const Icon(Icons.chevron_right,
                    color: AppTheme.textSecondary),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle:
                    GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 12),
                weekendStyle:
                    GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select Time',
            style: GoogleFonts.dmSans(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _timeSlots.length,
            itemBuilder: (_, index) {
              final time = _timeSlots[index];
              final isSelected = _selectedTime == time;
              return InkWell(
                onTap: () => setState(() => _selectedTime = time),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.secondary : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isSelected ? AppTheme.secondary : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _formatTime(time),
                      style: GoogleFonts.dmSans(
                        color:
                            isSelected ? Colors.black : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _notesController,
            label: 'Special Requests (Optional)',
            hint: 'Any special requests or notes...',
            maxLines: 3,
            prefixIcon: Icons.note_outlined,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildConfirmStep() {
    final servicesAsync = ref.watch(servicesProvider);

    return servicesAsync.when(
      data: (services) {
        final service = services.firstWhere(
          (s) => s.id == _selectedServiceId,
          orElse: () => services.first,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm Appointment',
                style: GoogleFonts.playfairDisplay(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 8),
              Text(
                'Please review your booking details',
                style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary, fontSize: 14),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _confirmRow(Icons.content_cut, 'Service', service.name),
                    const Divider(height: 24),
                    _confirmRow(
                      Icons.calendar_today,
                      'Date',
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                    const Divider(height: 24),
                    _confirmRow(
                      Icons.access_time,
                      'Time',
                      _selectedTime != null
                          ? _formatTime(_selectedTime!)
                          : 'Not selected',
                    ),
                    const Divider(height: 24),
                    _confirmRow(
                      Icons.person,
                      'Barber',
                      _selectedBarberId == null
                          ? 'Any Available'
                          : (_selectedBarberName ?? 'Selected Barber'),
                    ),
                    const Divider(height: 24),
                    _confirmRow(
                      Icons.timer,
                      'Duration',
                      '${service.durationMinutes} minutes',
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            color: AppTheme.secondary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Total Price',
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          '₱${service.price.toStringAsFixed(0)}',
                          style: GoogleFonts.dmSans(
                            color: AppTheme.secondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
              if (_notesController.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note,
                          color: AppTheme.textHint, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _notesController.text,
                          style: GoogleFonts.dmSans(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleBooking,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Confirm Booking',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(error: e.toString()),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.secondary, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style:
              GoogleFonts.dmSans(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    final canProceed = _canProceed();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.cardColor, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: canProceed ? () => setState(() => _step++) : null,
          child: Text(
            _step == 2 ? 'Review Booking' : 'Continue',
            style:
                GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  bool _canProceed() {
    switch (_step) {
      case 0:
        return _selectedServiceId != null;
      case 1:
        return true; // Barber is optional
      case 2:
        return _selectedTime != null;
      default:
        return true;
    }
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  Future<void> _handleBooking() async {
    final user = ref.read(authStateProvider).value;
    if (user == null || _selectedServiceId == null || _selectedTime == null) {
      return;
    }

    setState(() => _isLoading = true);

    late final String branchId;
    try {
      branchId = await ref.read(activeBranchIdProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active branch configured.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    final appointment = await ref
        .read(appointmentNotifierProvider.notifier)
        .createAppointment(
          customerId: user.id,
          serviceId: _selectedServiceId!,
          branchId: branchId,
          date: _selectedDate,
          time: _selectedTime!,
          barberId: _selectedBarberId,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (appointment != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
              const SizedBox(height: 16),
              Text(
                'Booking Confirmed!',
                style: GoogleFonts.playfairDisplay(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your appointment has been booked successfully.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Queue #${appointment.id.substring(0, 4).toUpperCase()}',
                style: GoogleFonts.dmSans(
                  color: AppTheme.secondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(AppRoutes.customerAppointments);
              },
              child: const Text('View Appointments'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(AppRoutes.queue);
              },
              child: const Text('Check Queue'),
            ),
          ],
        ),
      );
    } else {
      final state = ref.read(appointmentNotifierProvider);
      final message =
          state.error?.toString() ?? 'Booking failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
