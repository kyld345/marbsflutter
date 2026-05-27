// lib/features/barbers/domain/barber_provider.dart
// FIXED:
//  1. BarberNotifier now receives Ref so it can set/clear
//     adminCreationInProgressProvider during createBarberWithAccount.
//     This flag tells the router NOT to redirect while the admin's session
//     is temporarily replaced by the new barber's signUp session.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/barber_repository.dart';
import '../domain/barber_model.dart';
import '../../auth/domain/auth_provider.dart';

final barberRepositoryProvider = Provider<BarberRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BarberRepository(client);
});

final barbersProvider = FutureProvider<List<BarberModel>>((ref) async {
  final repo = ref.watch(barberRepositoryProvider);
  return repo.getBarbers(isAvailable: true);
});

final allBarbersProvider = FutureProvider<List<BarberModel>>((ref) async {
  final repo = ref.watch(barberRepositoryProvider);
  return repo.getBarbers();
});

final assignableBarberUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(barberRepositoryProvider);
  return repo.getUsersWithoutBarberProfile();
});

final activeBranchesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(barberRepositoryProvider);
  return repo.getActiveBranches();
});

final barberDetailProvider =
    FutureProvider.family<BarberModel, String>((ref, id) async {
  final repo = ref.watch(barberRepositoryProvider);
  return repo.getBarber(id);
});

class BarberNotifier extends StateNotifier<AsyncValue<void>> {
  final BarberRepository _repository;
  final Ref _ref;

  BarberNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> createBarber({
    String? userId,
    String? displayName,
    required String branchId,
    String? specialization,
    String? bio,
    int experienceYears = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createBarber(
        userId: userId,
        displayName: displayName,
        branchId: branchId,
        specialization: specialization,
        bio: bio,
        experienceYears: experienceYears,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> createBarberWithAccount({
    required String email,
    required String password,
    required String fullName,
    required String branchId,
    String? specialization,
    String? bio,
    int experienceYears = 0,
  }) async {
    state = const AsyncValue.loading();

    // FIX: Set the creation lock BEFORE calling signUp() so the router
    // redirect is suppressed when the auth state changes to the new barber.
    _ref.read(adminCreationInProgressProvider.notifier).state = true;

    try {
      await _repository.createBarberWithAccount(
        email: email,
        password: password,
        fullName: fullName,
        branchId: branchId,
        specialization: specialization,
        bio: bio,
        experienceYears: experienceYears,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    } finally {
      // Always release the lock, success or failure
      _ref.read(adminCreationInProgressProvider.notifier).state = false;
    }
  }

  Future<bool> updateBarber(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateBarber(id, updates);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> toggleAvailability(String barberId, bool isAvailable) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateBarber(barberId, {
        'is_available': isAvailable,
        'updated_at': DateTime.now().toIso8601String(),
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteBarber(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteBarber(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final barberNotifierProvider =
    StateNotifierProvider<BarberNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(barberRepositoryProvider);
  return BarberNotifier(repo, ref);
});
