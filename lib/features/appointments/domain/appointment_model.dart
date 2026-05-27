// lib/features/appointments/domain/appointment_model.dart
// FIXED: added derived getters for display names

import 'package:equatable/equatable.dart';

class AppointmentModel extends Equatable {
  final String id;
  final String? customerId;
  final String? barberId;
  final String? branchId;
  final String? serviceId;
  final DateTime appointmentDate;
  final String appointmentTime;
  final String? endTime;
  final String status;
  final String? notes;
  final double? totalPrice;
  final String paymentStatus;
  final bool isWalkIn;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations (joined data)
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? barber;
  final Map<String, dynamic>? service;
  final Map<String, dynamic>? branch;

  const AppointmentModel({
    required this.id,
    this.customerId,
    this.barberId,
    this.branchId,
    this.serviceId,
    required this.appointmentDate,
    required this.appointmentTime,
    this.endTime,
    required this.status,
    this.notes,
    this.totalPrice,
    required this.paymentStatus,
    required this.isWalkIn,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.barber,
    this.service,
    this.branch,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      barberId: json['barber_id'] as String?,
      branchId: json['branch_id'] as String?,
      serviceId: json['service_id'] as String?,
      appointmentDate: DateTime.parse(json['appointment_date'] as String),
      appointmentTime: json['appointment_time'] as String,
      endTime: json['end_time'] as String?,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      isWalkIn: json['is_walk_in'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Relations — 'customer' is the PostgREST alias for users!customer_id;
      // fall back to 'users' and 'customers' for any legacy queries.
      customer: _extractRelation(json, ['customer', 'users', 'customers']),
      barber: _extractRelation(json, ['barbers']),
      service: _extractRelation(json, ['services']),
      branch: _extractRelation(json, ['branches']),
    );
  }

  static Map<String, dynamic>? _extractRelation(
      Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      if (!json.containsKey(k) || json[k] == null) continue;
      final val = json[k];
      if (val is Map<String, dynamic>) return val;
      // Supabase can return a one-to-one join as a List when the FK direction
      // is ambiguous — take the first element in that case.
      if (val is List && val.isNotEmpty && val.first is Map<String, dynamic>) {
        return val.first as Map<String, dynamic>;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'customer_id': customerId,
        'barber_id': barberId,
        'branch_id': branchId,
        'service_id': serviceId,
        'appointment_date':
            '${appointmentDate.year}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}',
        'appointment_time': appointmentTime,
        'end_time': endTime,
        'status': status,
        'notes': notes,
        'total_price': totalPrice,
        'payment_status': paymentStatus,
        'is_walk_in': isWalkIn,
      };

  // ──────────────────────────────────────────
  // Derived display getters
  // ──────────────────────────────────────────

  String? get customerName {
    if (customer == null) return null;
    return customer!['full_name'] as String?;
  }

  String? get barberName {
    if (barber == null) return null;
    // barber join is: barbers { users { full_name } }
    final users = barber!['users'] as Map<String, dynamic>?;
    if (users != null) return users['full_name'] as String?;
    return barber!['display_name'] as String?;
  }

  String? get serviceName => service?['name'] as String?;

  double? get servicePrice => (service?['price'] as num?)?.toDouble();

  int? get serviceDuration => service?['duration_minutes'] as int?;

  String? get branchName => branch?['name'] as String?;

  String get formattedDate {
    final d = appointmentDate;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get formattedTime {
    if (appointmentTime.length >= 5) return appointmentTime.substring(0, 5);
    return appointmentTime;
  }

  bool get isUpcoming =>
      appointmentDate.isAfter(DateTime.now()) ||
      (appointmentDate.isAtSameMomentAs(DateTime.now()) &&
          status != 'completed' &&
          status != 'cancelled');

  bool get canCancel =>
      status == 'pending' || status == 'confirmed';

  bool get canReview =>
      status == 'completed';

  @override
  List<Object?> get props => [id, status, updatedAt];
}