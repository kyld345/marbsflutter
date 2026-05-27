// lib/features/appointments/domain/appointment_provider.dart
//
// CHANGES FROM ORIGINAL:
//  1. Added `search` field to AppointmentFilter so the provider signature
//     matches what AppointmentListScreen expects.  The filtering is still
//     done client-side for now (small dataset), but the field is wired
//     through so it can be switched to server-side search later without
//     breaking callers.
//  2. Added branchAppointmentsStreamProvider — a StreamProvider backed by
//     the new AppointmentRepository.streamAppointments() so screens that
//     need realtime updates can subscribe without manual polling.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment_model.dart';
import '../../auth/domain/auth_provider.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AppointmentRepository(client);
});

// Customer appointments
final customerAppointmentsProvider =
    FutureProvider.family<List<AppointmentModel>, String?>((ref, status) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.getCustomerAppointments(
    customerId: user.id,
    status: status,
  );
});

// All appointments (staff)
// BUG FIX: Added `search` field so this filter is a complete description of
// what the list screen requests.  Client-side filtering in
// AppointmentListScreen reads `filter.search` and applies it locally.
class AppointmentFilter extends Equatable {
  final String? status;
  final String? barberId;
  final String? branchId;
  final DateTime? date;
  final String? search; // ← ADDED (was missing, causing mismatch with UI)
  final int page;

  const AppointmentFilter({
    this.status,
    this.barberId,
    this.branchId,
    this.date,
    this.search,
    this.page = 0,
  });

  @override
  List<Object?> get props => [
        status,
        barberId,
        branchId,
        date?.toIso8601String(),
        search,
        page,
      ];
}

final allAppointmentsProvider =
    FutureProvider.family<List<AppointmentModel>, AppointmentFilter>(
        (ref, filter) async {
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.getAllAppointments(
    status: filter.status,
    barberId: filter.barberId,
    branchId: filter.branchId,
    date: filter.date,
    page: filter.page,
    // `search` is applied client-side by the screen; not passed to repo.
  );
});

// Single appointment
final appointmentDetailProvider =
    FutureProvider.family<AppointmentModel, String>((ref, id) async {
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.getAppointment(id);
});

// Today's stats
final todayStatsProvider =
    FutureProvider.family<Map<String, int>, String>((ref, branchId) async {
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.getTodayStats(branchId);
});

// BUG FIX: Added realtime stream provider using AppointmentRepository.streamAppointments().
// The original code had watchAppointments() in the repo but no corresponding
// StreamProvider, so realtime updates were never received on the appointments list.
final branchAppointmentsStreamProvider =
    StreamProvider.family<List<AppointmentModel>, String>((ref, branchId) {
  final repo = ref.watch(appointmentRepositoryProvider);
  return repo.streamAppointments(branchId);
});

// Appointment notifier for CRUD operations
class AppointmentNotifier extends StateNotifier<AsyncValue<void>> {
  final AppointmentRepository _repository;

  AppointmentNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<AppointmentModel?> createAppointment({
    required String customerId,
    required String serviceId,
    required String branchId,
    required DateTime date,
    required String time,
    String? barberId,
    String? notes,
    bool isWalkIn = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.createAppointment(
        customerId: customerId,
        serviceId: serviceId,
        branchId: branchId,
        date: date,
        time: time,
        barberId: barberId,
        notes: notes,
        isWalkIn: isWalkIn,
      );
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateStatus(id, status);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> cancelAppointment(String id) async {
    return updateStatus(id, 'cancelled');
  }

  Future<bool> updateAppointment(
      String id, Map<String, dynamic> updates) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateAppointment(id, updates);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteAppointment(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteAppointment(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final appointmentNotifierProvider =
    StateNotifierProvider<AppointmentNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(appointmentRepositoryProvider);
  return AppointmentNotifier(repo);
});