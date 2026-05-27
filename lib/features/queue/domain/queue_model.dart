// lib/features/queue/domain/queue_model.dart

import 'package:equatable/equatable.dart';

class QueueModel extends Equatable {
  final String id;
  final String? appointmentId;
  final String branchId;
  final int queueNumber;
  final String status;
  final DateTime? checkInTime;
  final DateTime? calledTime;
  final DateTime? startServiceTime;
  final DateTime? endServiceTime;
  final int? estimatedWaitMinutes;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations
  final Map<String, dynamic>? appointment;

  const QueueModel({
    required this.id,
    this.appointmentId,
    required this.branchId,
    required this.queueNumber,
    required this.status,
    this.checkInTime,
    this.calledTime,
    this.startServiceTime,
    this.endServiceTime,
    this.estimatedWaitMinutes,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.appointment,
  });

  factory QueueModel.fromJson(Map<String, dynamic> json) {
    return QueueModel(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String?,
      branchId: json['branch_id'] as String,
      queueNumber: json['queue_number'] as int,
      status: json['status'] as String,
      checkInTime: json['check_in_time'] != null
          ? DateTime.parse(json['check_in_time'] as String)
          : null,
      calledTime: json['called_time'] != null
          ? DateTime.parse(json['called_time'] as String)
          : null,
      startServiceTime: json['start_service_time'] != null
          ? DateTime.parse(json['start_service_time'] as String)
          : null,
      endServiceTime: json['end_service_time'] != null
          ? DateTime.parse(json['end_service_time'] as String)
          : null,
      estimatedWaitMinutes: json['estimated_wait_minutes'] as int?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // BUG FIX: guard against Supabase returning a List instead of a Map
      // when the FK relationship direction is ambiguous in PostgREST.
      appointment: _extractAppointment(json['appointments']),
    );
  }

  static Map<String, dynamic>? _extractAppointment(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is List && raw.isNotEmpty && raw.first is Map<String, dynamic>) {
      return raw.first as Map<String, dynamic>;
    }
    return null;
  }

  String get customerName {
    final apt = appointment;
    if (apt == null) return 'Walk-in #$queueNumber';
    // 'customer' is the PostgREST alias set in the repository query;
    // fall back to the legacy 'users' key for safety.
    final customer = (apt['customer'] ?? apt['users']) as Map<String, dynamic>?;
    return customer?['full_name'] as String? ?? 'Customer #$queueNumber';
  }

  String get serviceName {
    final apt = appointment;
    if (apt == null) return 'Service';
    final service = apt['services'] as Map<String, dynamic>?;
    return service?['name'] as String? ?? 'Service';
  }

  String get barberName {
    final apt = appointment;
    if (apt == null) return 'Unassigned';
    final barber = apt['barbers'] as Map<String, dynamic>?;
    if (barber == null) return 'Unassigned';
    final users = barber['users'] as Map<String, dynamic>?;
    return users?['full_name'] as String? ?? 'Unassigned';
  }

  String get waitTime {
    if (estimatedWaitMinutes == null) return 'N/A';
    if (estimatedWaitMinutes! < 60) return '${estimatedWaitMinutes}m';
    final hours = estimatedWaitMinutes! ~/ 60;
    final mins = estimatedWaitMinutes! % 60;
    return '${hours}h ${mins}m';
  }

  @override
  List<Object?> get props => [id, status, queueNumber, updatedAt];
}