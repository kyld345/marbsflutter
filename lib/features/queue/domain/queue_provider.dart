// lib/features/queue/domain/queue_provider.dart
//
// FIXES:
//  1. [SILENT FAILURE] todayQueueProvider previously swallowed errors from
//     activeBranchIdProvider by checking `.value` (null while loading OR on
//     error) and returning an empty stream. The UI had no way to distinguish
//     "still loading" from "no active branch configured". The provider now
//     propagates the AsyncError so the screen can show a retry option.
//  2. queueStatsProvider uses the same guarded branch lookup so stats also
//     surface an error instead of returning empty/zero counts.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/queue_repository.dart';
import '../domain/queue_model.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/providers/branch_provider.dart';

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return QueueRepository(client);
});

// ──────────────────────────────────────────────────────────────
// Today's queue (realtime)
// ──────────────────────────────────────────────────────────────

/// Streams today's queue for the active branch, re-fetching on every
/// realtime change event so joined data (customer, service, barber) is
/// always fresh.
///
/// FIX: propagates activeBranchIdProvider errors rather than silently
/// returning an empty stream.
final todayQueueProvider = StreamProvider<List<QueueModel>>((ref) async* {
  // Await branch resolution; throws if no active branch found.
  final branchId = await ref.watch(activeBranchIdProvider.future);

  final repo = ref.watch(queueRepositoryProvider);

  // watchQueue triggers on any queue row change for this branch.
  // asyncMap re-fetches the fully-joined list on each event.
  yield* repo
      .watchQueue(branchId)
      .asyncMap((_) => repo.getTodayQueue(branchId));
});

// ──────────────────────────────────────────────────────────────
// Queue stats
// ──────────────────────────────────────────────────────────────

final queueStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  // Re-fetch whenever the queue stream emits (keeps stats in sync).
  ref.watch(todayQueueProvider);

  // FIX: use .future to propagate errors from activeBranchIdProvider.
  final branchId = await ref.watch(activeBranchIdProvider.future);
  final repo = ref.watch(queueRepositoryProvider);
  return repo.getQueueStats(branchId);
});

// ──────────────────────────────────────────────────────────────
// My queue entry (customer view)
// ──────────────────────────────────────────────────────────────

final myQueueEntryProvider =
    FutureProvider.family<QueueModel?, String>((ref, appointmentId) async {
  final repo = ref.watch(queueRepositoryProvider);
  return repo.getMyQueueEntry(appointmentId);
});

// ──────────────────────────────────────────────────────────────
// Queue notifier (mutations)
// ──────────────────────────────────────────────────────────────

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

  Future<bool> callNext(String id) async => updateStatus(id, 'in_progress');

  Future<bool> completeService(String id) async =>
      updateStatus(id, 'completed');

  Future<bool> skipCustomer(String id) async =>
      updateStatus(id, 'skipped');
}

final queueNotifierProvider =
    StateNotifierProvider<QueueNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(queueRepositoryProvider);
  return QueueNotifier(repo);
});