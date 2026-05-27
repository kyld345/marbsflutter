// lib/features/schedules/domain/schedule_model.dart

import 'package:equatable/equatable.dart';

class ScheduleModel extends Equatable {
  final String id;
  final String barberId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isDayOff;
  final Map<String, dynamic>? barber;

  const ScheduleModel({
    required this.id,
    required this.barberId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isDayOff,
    this.barber,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) => ScheduleModel(
        id: json['id'] as String,
        barberId: json['barber_id'] as String,
        dayOfWeek: json['day_of_week'] as int,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        isDayOff: json['is_day_off'] as bool? ?? false,
        barber: json['barbers'] as Map<String, dynamic>?,
      );

  String get dayName {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[dayOfWeek];
  }

  String get barberName {
    final b = barber;
    if (b == null) return 'Unknown';
    final u = b['users'] as Map<String, dynamic>?;
    return u?['full_name'] as String? ?? 'Unknown';
  }

  @override
  List<Object?> get props => [id, barberId, dayOfWeek, isDayOff];
}