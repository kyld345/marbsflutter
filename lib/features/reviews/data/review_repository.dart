// lib/features/reviews/data/review_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/review_model.dart';
import '../../../core/config/supabase_config.dart';

class ReviewRepository {
  final SupabaseClient _client;
  ReviewRepository(this._client);

  Future<List<ReviewModel>> getReviews({
    String? barberId,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client
        .from(SupabaseConfig.reviewsTable)
        .select('*, users!customer_id(full_name, avatar_url), barbers!barber_id(*, users(full_name))')
        .eq('is_published', true);

    if (barberId != null) query = query.eq('barber_id', barberId);

    final response = await query
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return response.map((j) => ReviewModel.fromJson(j)).toList();
  }

  Future<List<ReviewModel>> getMyReviews(String customerId) async {
    final response = await _client
        .from(SupabaseConfig.reviewsTable)
        .select('*, users!customer_id(full_name), barbers!barber_id(*, users(full_name))')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return response.map((j) => ReviewModel.fromJson(j)).toList();
  }

  Future<ReviewModel> createReview({
    required String customerId,
    required String barberId,
    required String appointmentId,
    required int rating,
    String? comment,
  }) async {
    final response = await _client
        .from(SupabaseConfig.reviewsTable)
        .insert({
          'customer_id': customerId,
          'barber_id': barberId,
          'appointment_id': appointmentId,
          'rating': rating,
          'comment': comment,
          'is_published': true,
        })
        .select('*, users!customer_id(full_name), barbers!barber_id(*, users(full_name))')
        .single();

    // Update barber rating
    await _updateBarberRating(barberId);

    return ReviewModel.fromJson(response);
  }

  Future<void> _updateBarberRating(String barberId) async {
    final reviews = await _client
        .from(SupabaseConfig.reviewsTable)
        .select('rating')
        .eq('barber_id', barberId)
        .eq('is_published', true);

    if (reviews.isEmpty) return;

    final total = reviews.fold<int>(0, (sum, r) => sum + (r['rating'] as int));
    final avg = total / reviews.length;

    await _client.from(SupabaseConfig.barbersTable).update({
      'rating': avg,
      'total_reviews': reviews.length,
    }).eq('id', barberId);
  }

  Future<void> deleteReview(String id) async {
    await _client.from(SupabaseConfig.reviewsTable).delete().eq('id', id);
  }
}