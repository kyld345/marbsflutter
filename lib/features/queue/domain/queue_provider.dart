// lib/features/queue/domain/queue_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/queue_repository.dart';
import '../domain/queue_model.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/providers/branch_provider.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return QueueRepository(client);
});

// Today's queue (with realtime)
final todayQueueProvider = StreamProvider<List<QueueModel>>((ref) {
  final branchId = ref.watch(activeBranchIdProvider).value;
  if (branchId == null) {
    return Stream.value([]);
  }

  final repo = ref.watch(queueRepositoryProvider);
  return repo
      .watchQueue(branchId)
      .asyncMap((_) async => repo.getTodayQueue(branchId));
});

// Queue stats
final queueStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  // Re-fetch when queue changes
  ref.watch(todayQueueProvider);
  final branchId = await ref.watch(activeBranchIdProvider.future);
  final repo = ref.watch(queueRepositoryProvider);
  return repo.getQueueStats(branchId);
});

// My queue entry (customer)
final myQueueEntryProvider =
    FutureProvider.family<QueueModel?, String>((ref, appointmentId) async {
  final repo = ref.watch(queueRepositoryProvider);
  return repo.getMyQueueEntry(appointmentId);
});

// Queue notifier for mutations
class QueueNotifier extends StateNotifier<AsyncValue<void>> {
  final QueueRepository _repository;

  QueueNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<bool> updateStatus(String id, String status) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateQueueStatus(id, status);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<QueueModel?> addWalkIn({
    required String branchId,
    required String serviceId,
    String? barberId,
    String? customerName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.addWalkIn(
        branchId: branchId,
        serviceId: serviceId,
        barberId: barberId,
        customerName: customerName,
      );
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> callNext(String id) async {
    return updateStatus(id, 'in_progress');
  }

  Future<bool> completeService(String id) async {
    return updateStatus(id, 'completed');
  }

  Future<bool> skipCustomer(String id) async {
    return updateStatus(id, 'skipped');
  }
}

final queueNotifierProvider =
    StateNotifierProvider<QueueNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(queueRepositoryProvider);
  return QueueNotifier(repo);
});
