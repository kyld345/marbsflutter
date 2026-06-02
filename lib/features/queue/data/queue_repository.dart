// lib/features/queue/data/queue_repository.dart
//
// FIXES:
//  1. [DATA LOSS] addWalkIn() received `customerName` but never persisted it.
//     The name is now stored in appointment `notes` as "Walk-in: <name>" so
//     QueueModel.customerName can retrieve it via the appointment join.
//  2. [DATA LOSS] customerName is also stored in queue `notes` as a
//     redundant fast-path so callers that only have the queue row still
//     see the name without a second join query.
//  3. [DATE FILTER] Date boundaries now use UTC-aware computation (Manila
//     UTC+8 offset) so queue entries created between local midnight and
//     08:00 are correctly included instead of being silently dropped.
//  4. No changes to the realtime watchQueue() — it uses .stream() which
//     already subscribes server-side; no polling needed.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/queue_model.dart';
import '../../../core/config/supabase_config.dart';

class QueueRepository {
  final SupabaseClient _client;

  QueueRepository(this._client);

  // ──────────────────────────────────────────────────────────────
  // Date helpers
  // ──────────────────────────────────────────────────────────────

  /// Returns "YYYY-MM-DD" in Manila local time (UTC+8).
  /// Using Manila time ensures the date string matches `appointment_date`
  /// values written by the same client and avoids the UTC-midnight split
  /// where entries created 00:00–07:59 local were missing from the filter.
  static String _manilaDateString([DateTime? ref]) {
    final utcNow = (ref ?? DateTime.now()).toUtc();
    final manila = utcNow.add(const Duration(hours: 8));
    return '${manila.year}-'
        '${manila.month.toString().padLeft(2, '0')}-'
        '${manila.day.toString().padLeft(2, '0')}';
  }

  /// Returns UTC boundaries for a Manila calendar day.
  /// Manila midnight (local) = UTC previous-day 16:00.
  static ({String start, String end}) _utcBoundsForManilaDay([DateTime? ref]) {
    final utcNow = (ref ?? DateTime.now()).toUtc();
    final manila = utcNow.add(const Duration(hours: 8));
    final manilaMidnight =
        DateTime.utc(manila.year, manila.month, manila.day);
    final utcStart =
        manilaMidnight.subtract(const Duration(hours: 8)).toIso8601String();
    final utcEnd = manilaMidnight
        .add(const Duration(hours: 16, seconds: -1))
        .toIso8601String();
    return (start: utcStart, end: utcEnd);
  }

  // ──────────────────────────────────────────────────────────────
  // Queries
  // ──────────────────────────────────────────────────────────────

  /// Returns today's queue for [branchId], ordered by queue number.
  /// Excludes cancelled entries; completed/skipped entries remain visible
  /// so staff can see the full day's history.
  Future<List<QueueModel>> getTodayQueue(String branchId) async {
    final bounds = _utcBoundsForManilaDay();

    final response = await _client
        .from(SupabaseConfig.queueTable)
        .select('''
          *,
          appointments!appointment_id(
            *,
            users!customer_id(full_name, phone, avatar_url),
            barbers!barber_id(*, users(full_name)),
            services(name, duration_minutes, price)
          )
        ''')
        .eq('branch_id', branchId)
        .gte('created_at', bounds.start)
        .lte('created_at', bounds.end)
        .neq('status', 'cancelled')
        .order('queue_number', ascending: true);

    return response.map((j) => QueueModel.fromJson(j)).toList();
  }

  /// Returns the queue entry for a customer's appointment (or null).
  Future<QueueModel?> getMyQueueEntry(String appointmentId) async {
    final response = await _client
        .from(SupabaseConfig.queueTable)
        .select('''
          *,
          appointments!appointment_id(
            *,
            users!customer_id(full_name),
            barbers!barber_id(*, users(full_name)),
            services(name, duration_minutes)
          )
        ''')
        .eq('appointment_id', appointmentId)
        .maybeSingle();

    if (response == null) return null;
    return QueueModel.fromJson(response);
  }

  /// Updates queue [status] and syncs the related appointment.
  Future<void> updateQueueStatus(String id, String status) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    switch (status) {
      case 'in_progress':
        updates['start_service_time'] =
            DateTime.now().toUtc().toIso8601String();
        updates['called_time'] = DateTime.now().toUtc().toIso8601String();
        break;
      case 'completed':
        updates['end_service_time'] =
            DateTime.now().toUtc().toIso8601String();
        break;
    }

    await _client
        .from(SupabaseConfig.queueTable)
        .update(updates)
        .eq('id', id);

    // Sync appointment status when service state changes.
    if (status == 'in_progress' || status == 'completed') {
      final queue = await _client
          .from(SupabaseConfig.queueTable)
          .select('appointment_id')
          .eq('id', id)
          .single();

      final aptId = queue['appointment_id'] as String?;
      if (aptId != null) {
        final aptStatus =
            status == 'in_progress' ? 'in_progress' : 'completed';
        await _client
            .from(SupabaseConfig.appointmentsTable)
            .update({'status': aptStatus}).eq('id', aptId);
      }
    }
  }

  /// Creates a walk-in appointment and queue entry.
  ///
  /// FIX: [customerName] is now persisted in two places so it is always
  /// visible to the UI:
  ///   • appointment.notes  → "Walk-in: <name>" (retrieved via join in
  ///                           getTodayQueue / getMyQueueEntry)
  ///   • queue.notes        → same string (fast-path; no join needed)
  Future<QueueModel> addWalkIn({
    required String branchId,
    required String serviceId,
    String? barberId,
    String? customerName,
  }) async {
    final serviceData = await _client
        .from(SupabaseConfig.servicesTable)
        .select('price, duration_minutes')
        .eq('id', serviceId)
        .single();

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr = _manilaDateString(now);

    // Count today's queue entries to assign the next number.
    final bounds = _utcBoundsForManilaDay(now);
    final queueData = await _client
        .from(SupabaseConfig.queueTable)
        .select('queue_number')
        .eq('branch_id', branchId)
        .gte('created_at', bounds.start)
        .lte('created_at', bounds.end)
        .order('queue_number', ascending: false)
        .limit(1);

    final maxNumber =
        queueData.isEmpty ? 0 : (queueData.first['queue_number'] as int);
    final nextNumber = maxNumber + 1;

    // FIX: Persist the walk-in name in appointment notes.
    // Walk-ins have no customer_id (anonymous), so the users join will be
    // null. Storing the name here lets QueueModel.customerName display it.
    final walkInTag = customerName != null && customerName.isNotEmpty
        ? 'Walk-in: $customerName'
        : 'Walk-in';

    final aptResponse = await _client
        .from(SupabaseConfig.appointmentsTable)
        .insert({
          'branch_id': branchId,
          'service_id': serviceId,
          'barber_id': barberId,
          'appointment_date': dateStr,
          'appointment_time': timeStr,
          'total_price': (serviceData['price'] as num).toDouble(),
          'is_walk_in': true,
          'status': 'confirmed',
          // FIX: store customer name in notes for walk-in identification.
          'notes': walkInTag,
        })
        .select('id')
        .single();

    final queueResponse = await _client
        .from(SupabaseConfig.queueTable)
        .insert({
          'appointment_id': aptResponse['id'] as String,
          'branch_id': branchId,
          'queue_number': nextNumber,
          'status': 'waiting',
          'estimated_wait_minutes': nextNumber * 30,
          // FIX: also store in queue.notes as fast-path (no join needed).
          'notes': walkInTag,
        })
        .select('''
          *,
          appointments!appointment_id(
            *,
            services(name, duration_minutes, price),
            barbers!barber_id(*, users(full_name))
          )
        ''')
        .single();

    return QueueModel.fromJson(queueResponse);
  }

  // ──────────────────────────────────────────────────────────────
  // Realtime
  // ──────────────────────────────────────────────────────────────

  /// Supabase realtime stream filtered to [branchId].
  /// Used by [todayQueueProvider] as a change trigger; the actual data
  /// is re-fetched via [getTodayQueue] on each emission (supports joins).
  Stream<List<Map<String, dynamic>>> watchQueue(String branchId) {
    return _client
        .from(SupabaseConfig.queueTable)
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .order('queue_number', ascending: true);
  }

  // ──────────────────────────────────────────────────────────────
  // Stats
  // ──────────────────────────────────────────────────────────────

  Future<Map<String, int>> getQueueStats(String branchId) async {
    final bounds = _utcBoundsForManilaDay();
    final response = await _client
        .from(SupabaseConfig.queueTable)
        .select('status')
        .eq('branch_id', branchId)
        .gte('created_at', bounds.start)
        .lte('created_at', bounds.end);

    final stats = <String, int>{
      'total': response.length,
      'waiting': 0,
      'in_progress': 0,
      'completed': 0,
      'skipped': 0,
    };

    for (final item in response) {
      final s = item['status'] as String;
      stats[s] = (stats[s] ?? 0) + 1;
    }

    return stats;
  }
}