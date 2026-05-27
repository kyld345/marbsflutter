// lib/features/barbers/domain/barber_model.dart

import 'package:equatable/equatable.dart';

class BarberModel extends Equatable {
  final String id;
  final String? displayNameOverride;
  final String? userId;
  final String? branchId;
  final String? specialization;
  final String? bio;
  final int experienceYears;
  final double rating;
  final int totalReviews;
  final bool isAvailable;
  final String? avatarUrl;
  final DateTime createdAt;

  // Relations
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? branch;

  const BarberModel({
    required this.id,
    this.displayNameOverride,
    this.userId,
    this.branchId,
    this.specialization,
    this.bio,
    required this.experienceYears,
    required this.rating,
    required this.totalReviews,
    required this.isAvailable,
    this.avatarUrl,
    required this.createdAt,
    this.user,
    this.branch,
  });

  factory BarberModel.fromJson(Map<String, dynamic> json) {
    return BarberModel(
      id: json['id'] as String,
      displayNameOverride: json['display_name'] as String?,
      userId: json['user_id'] as String?,
      branchId: json['branch_id'] as String?,
      specialization: json['specialization'] as String?,
      bio: json['bio'] as String?,
      experienceYears: json['experience_years'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: json['users'] as Map<String, dynamic>?,
      branch: json['branches'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayNameOverride,
        'user_id': userId,
        'branch_id': branchId,
        'specialization': specialization,
        'bio': bio,
        'experience_years': experienceYears,
        'is_available': isAvailable,
        'avatar_url': avatarUrl,
      };

  String get displayName =>
      (user?['full_name'] as String?) ??
      displayNameOverride ??
      'Barber #${id.substring(0, 4)}';

  String get branchName => (branch?['name'] as String?) ?? 'Main Branch';

  @override
  List<Object?> get props => [id, isAvailable, rating];
}
