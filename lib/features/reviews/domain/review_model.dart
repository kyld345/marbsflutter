// lib/features/reviews/domain/review_model.dart

import 'package:equatable/equatable.dart';

class ReviewModel extends Equatable {
  final String id;
  final String customerId;
  final String barberId;
  final String appointmentId;
  final int rating;
  final String? comment;
  final bool isPublished;
  final DateTime createdAt;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? barber;

  const ReviewModel({
    required this.id,
    required this.customerId,
    required this.barberId,
    required this.appointmentId,
    required this.rating,
    this.comment,
    required this.isPublished,
    required this.createdAt,
    this.customer,
    this.barber,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: json['id'] as String,
        customerId: json['customer_id'] as String,
        barberId: json['barber_id'] as String,
        appointmentId: json['appointment_id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
        isPublished: json['is_published'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        customer: json['users'] as Map<String, dynamic>?,
        barber: json['barbers'] as Map<String, dynamic>?,
      );

  String get customerName =>
      (customer?['full_name'] as String?) ?? 'Anonymous';

  String get barberName {
    final b = barber;
    if (b == null) return 'Unknown';
    final u = b['users'] as Map<String, dynamic>?;
    return u?['full_name'] as String? ?? 'Unknown';
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays < 1) return 'Today';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  @override
  List<Object?> get props => [id, rating];
}