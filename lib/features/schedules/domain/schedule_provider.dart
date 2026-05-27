// lib/features/schedules/domain/schedule_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/schedule_repository.dart';
import '../domain/schedule_model.dart';
import '../../auth/domain/auth_provider.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ScheduleRepository(client);
});

final schedulesProvider =
    FutureProvider.family<List<ScheduleModel>, String?>((ref, barberId) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  return repo.getSchedules(barberId: barberId);
});

class ScheduleNotifier extends StateNotifier<AsyncValue<void>> {
  final ScheduleRepository _repository;
  ScheduleNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<bool> upsertSchedule({
    required String barberId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    bool isDayOff = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.upsertSchedule(
        barberId: barberId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        isDayOff: isDayOff,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final scheduleNotifierProvider =
    StateNotifierProvider<ScheduleNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return ScheduleNotifier(repo);
});