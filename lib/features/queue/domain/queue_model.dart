// lib/features/queue/domain/queue_model.dart
//
// FIXES:
//  1. [DISPLAY BUG] customerName getter now reads the walk-in name stored
//     in appointment.notes (written by the fixed QueueRepository.addWalkIn).
//     Previously, walk-in entries always showed "Walk-in #N" because the
//     customer name was collected in the dialog but never persisted.
//  2. [DISPLAY BUG] Fast-path: if the appointment join is absent (possible
//     with certain RLS policies), the getter now falls back to queue.notes,
//     which also stores the walk-in tag since the same fix.
//  3. Existing _extractAppointment guard (List vs Map) is preserved.

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
      // Guard against Supabase returning a List instead of a Map when the
      // FK relationship direction is ambiguous in PostgREST.
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

  // ──────────────────────────────────────────────────────────────
  // Derived display getters
  // ──────────────────────────────────────────────────────────────

  /// Returns the customer's display name.
  ///
  /// Priority:
  ///  1. Users join (authenticated customer with a profile)
  ///  2. Walk-in name stored in appointment.notes as "Walk-in: <name>"
  ///  3. Walk-in name stored in queue.notes (fast-path; same format)
  ///  4. Generic "Walk-in #N" fallback
  String get customerName {
    final apt = appointment;

    // 1. Authenticated customer joined via users!customer_id.
    if (apt != null) {
      final customer =
          (apt['customer'] ?? apt['users']) as Map<String, dynamic>?;
      final name = customer?['full_name'] as String?;
      if (name != null && name.isNotEmpty) return name;

      // 2. Walk-in name persisted in appointment.notes ("Walk-in: <name>").
      final aptNotes = apt['notes'] as String?;
      final fromAptNotes = _extractWalkInName(aptNotes);
      if (fromAptNotes != null) return fromAptNotes;
    }

    // 3. Walk-in name persisted in queue.notes (fast-path, no join needed).
    final fromQueueNotes = _extractWalkInName(notes);
    if (fromQueueNotes != null) return fromQueueNotes;

    // 4. Generic fallback.
    return 'Walk-in #$queueNumber';
  }

  /// Extracts the customer name from a "Walk-in: <name>" notes string.
  /// Returns null if the string is absent or in a different format.
  static String? _extractWalkInName(String? notesStr) {
    if (notesStr == null || notesStr.isEmpty) return null;
    if (notesStr.startsWith('Walk-in: ')) {
      final name = notesStr.substring('Walk-in: '.length).trim();
      return name.isNotEmpty ? name : null;
    }
    return null;
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