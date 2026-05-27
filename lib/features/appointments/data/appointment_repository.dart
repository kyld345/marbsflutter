// lib/features/appointments/data/appointment_repository.dart
//
// CHANGES FROM ORIGINAL:
//  1. Removed dead `search` parameter from getAllAppointments().
//     The parameter existed in the signature but was never applied to the
//     Supabase query; filtering happens client-side in AppointmentListScreen.
//     Keeping it silently misled callers into thinking server-side search
//     was active.
//  2. Added streamAppointments() StreamProvider-ready helper that wraps
//     watchAppointments() with a full select so callers get AppointmentModel
//     objects instead of raw maps.  The original watchAppointments() was
//     declared but never consumed by any provider.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/appointment_model.dart';
import '../../../core/config/supabase_config.dart';

class AppointmentRepository {
  final SupabaseClient _client;

  AppointmentRepository(this._client);

  // Create appointment
  Future<AppointmentModel> createAppointment({
    required String customerId,
    required String serviceId,
    required String branchId,
    required DateTime date,
    required String time,
    String? barberId,
    String? notes,
    bool isWalkIn = false,
  }) async {
    final service = await _client
        .from(SupabaseConfig.servicesTable)
        .select('price, duration_minutes')
        .eq('id', serviceId)
        .single();

    final price = (service['price'] as num).toDouble();
    final duration = service['duration_minutes'] as int;

    // Calculate end time — only use HH and MM parts so it works whether
    // the caller passes 'HH:MM' or 'HH:MM:SS'.
    final timeParts = time.split(':');
    final startMinutes = int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
    final endMinutes = startMinutes + duration;
    final endTime =
        '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:${(endMinutes % 60).toString().padLeft(2, '0')}';

    final data = {
      'customer_id': customerId,
      'service_id': serviceId,
      'branch_id': branchId,
      'barber_id': barberId,
      'appointment_date': date.toIso8601String().split('T').first,
      'appointment_time': time,
      'end_time': endTime,
      'total_price': price,
      'notes': notes,
      'is_walk_in': isWalkIn,
      'status': 'pending',
      'payment_status': 'unpaid',
    };

    final response = await _client
        .from(SupabaseConfig.appointmentsTable)
        .insert(data)
        .select(
            '*, users!customer_id(full_name, phone), barbers!barber_id(*, users(full_name)), services(*), branches(*)')
        .single();

    // Add to queue as best-effort. Appointment creation should not fail
    // if queue insertion is blocked by policy or temporary backend issues.
    try {
      await _addToQueue(response['id'] as String, branchId, date);
    } catch (_) {
      // Queue entry can be created by staff later if customer-side insert is restricted.
    }

    return AppointmentModel.fromJson(response);
  }

  Future<void> _addToQueue(
      String appointmentId, String branchId, DateTime date) async {
    // Get current max queue number for today
    final today = date.toIso8601String().split('T').first;
    final queueData = await _client
        .from(SupabaseConfig.queueTable)
        .select('queue_number')
        .eq('branch_id', branchId)
        .gte('created_at', '${today}T00:00:00')
        .lte('created_at', '${today}T23:59:59')
        .order('queue_number', ascending: false)
        .limit(1);

    final maxNumber =
        queueData.isEmpty ? 0 : (queueData.first['queue_number'] as int);

    await _client.from(SupabaseConfig.queueTable).insert({
      'appointment_id': appointmentId,
      'branch_id': branchId,
      'queue_number': maxNumber + 1,
      'status': 'waiting',
      'estimated_wait_minutes': (maxNumber + 1) * 30,
    });
  }

  // Get appointments for customer
  Future<List<AppointmentModel>> getCustomerAppointments({
    required String customerId,
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client
        .from(SupabaseConfig.appointmentsTable)
        .select(
            '*, users!customer_id(full_name, phone), barbers!barber_id(*, users(full_name)), services(*), branches(*)')
        .eq('customer_id', customerId);

    if (status != null) query = query.eq('status', status);

    final response = await query
        .order('appointment_date', ascending: false)
        .order('appointment_time', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return response.map((j) => AppointmentModel.fromJson(j)).toList();
  }

  // Get all appointments (staff)
  // BUG FIX: Removed the `search` parameter that was declared but never
  // applied to the query. Client-side filtering in AppointmentListScreen
  // handles the search, so the dead parameter was misleading.
  Future<List<AppointmentModel>> getAllAppointments({
    String? status,
    String? barberId,
    String? branchId,
    DateTime? date,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client.from(SupabaseConfig.appointmentsTable).select(
        '*, users!customer_id(full_name, phone), barbers!barber_id(*, users(full_name)), services(*), branches(*)');

    if (status != null) query = query.eq('status', status);
    if (barberId != null) query = query.eq('barber_id', barberId);
    if (branchId != null) query = query.eq('branch_id', branchId);
    if (date != null) {
      final dateStr = date.toIso8601String().split('T').first;
      query = query.eq('appointment_date', dateStr);
    }

    final response = await query
        .order('appointment_date', ascending: false)
        .order('appointment_time', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return response.map((j) => AppointmentModel.fromJson(j)).toList();
  }

  // Get single appointment
  Future<AppointmentModel> getAppointment(String id) async {
    final response = await _client
        .from(SupabaseConfig.appointmentsTable)
        .select(
            '*, users!customer_id(full_name, phone, avatar_url), barbers!barber_id(*, users(full_name, avatar_url)), services(*), branches(*)')
        .eq('id', id)
        .single();

    return AppointmentModel.fromJson(response);
  }

  // Update appointment status
  Future<void> updateStatus(String id, String status) async {
    await _client.from(SupabaseConfig.appointmentsTable).update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', id);
  }

  // Update appointment
  Future<void> updateAppointment(
      String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client
        .from(SupabaseConfig.appointmentsTable)
        .update(updates)
        .eq('id', id);
  }

  // Cancel appointment
  Future<void> cancelAppointment(String id) async {
    await updateStatus(id, 'cancelled');
    // Update queue
    final queueEntry = await _client
        .from(SupabaseConfig.queueTable)
        .select('id')
        .eq('appointment_id', id)
        .maybeSingle();

    if (queueEntry != null) {
      await _client
          .from(SupabaseConfig.queueTable)
          .update({'status': 'cancelled'}).eq('id', queueEntry['id'] as String);
    }
  }

  // Delete appointment (admin only)
  Future<void> deleteAppointment(String id) async {
    await _client.from(SupabaseConfig.appointmentsTable).delete().eq('id', id);
  }

  // Get today's stats
  Future<Map<String, int>> getTodayStats(String branchId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await _client
        .from(SupabaseConfig.appointmentsTable)
        .select('status')
        .eq('branch_id', branchId)
        .eq('appointment_date', today);

    final stats = <String, int>{
      'total': response.length,
      'pending': 0,
      'confirmed': 0,
      'in_progress': 0,
      'completed': 0,
      'cancelled': 0,
    };

    for (final item in response) {
      final status = item['status'] as String;
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }

  // Realtime raw stream (used internally by streamAppointments)
  Stream<List<Map<String, dynamic>>> watchAppointments(String branchId) {
    return _client
        .from(SupabaseConfig.appointmentsTable)
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .order('appointment_date')
        .order('appointment_time');
  }

  // BUG FIX: Added typed stream that emits AppointmentModel lists so
  // StreamProviders can consume it without raw map manipulation.
  Stream<List<AppointmentModel>> streamAppointments(String branchId) {
    return watchAppointments(branchId).asyncMap((_) async {
      return getAllAppointments(branchId: branchId);
    });
  }
}