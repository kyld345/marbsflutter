// lib/features/services/domain/service_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/service_repository.dart';
import '../domain/service_model.dart';
import '../../auth/domain/auth_provider.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ServiceRepository(client);
});

final servicesProvider = FutureProvider<List<ServiceModel>>((ref) async {
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getServices(isActive: true);
});

final allServicesProvider = FutureProvider<List<ServiceModel>>((ref) async {
  final repo = ref.watch(serviceRepositoryProvider);
  return repo.getServices();
});

class ServiceNotifier extends StateNotifier<AsyncValue<void>> {
  final ServiceRepository _repository;
  ServiceNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<bool> createService({
    required String name,
    String? description,
    required double price,
    required int durationMinutes,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createService(
        name: name,
        description: description,
        price: price,
        durationMinutes: durationMinutes,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateService(String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateService(id, updates);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteService(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final serviceNotifierProvider =
    StateNotifierProvider<ServiceNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(serviceRepositoryProvider);
  return ServiceNotifier(repo);
});