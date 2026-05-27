// lib/features/reviews/domain/review_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/review_repository.dart';
import '../domain/review_model.dart';
import '../../auth/domain/auth_provider.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ReviewRepository(client);
});

final reviewsProvider =
    FutureProvider.family<List<ReviewModel>, String?>((ref, barberId) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getReviews(barberId: barberId);
});

final myReviewsProvider = FutureProvider<List<ReviewModel>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getMyReviews(user.id);
});

class ReviewNotifier extends StateNotifier<AsyncValue<void>> {
  final ReviewRepository _repository;
  ReviewNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<bool> createReview({
    required String customerId,
    required String barberId,
    required String appointmentId,
    required int rating,
    String? comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createReview(
        customerId: customerId,
        barberId: barberId,
        appointmentId: appointmentId,
        rating: rating,
        comment: comment,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteReview(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteReview(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final reviewNotifierProvider =
    StateNotifierProvider<ReviewNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(reviewRepositoryProvider);
  return ReviewNotifier(repo);
});