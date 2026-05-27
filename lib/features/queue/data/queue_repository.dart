// lib/features/queue/data/queue_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/queue_model.dart';
import '../../../core/config/supabase_config.dart';

class QueueRepository {
  final SupabaseClient _client;

  QueueRepository(this._client);

  // Get today's queue for a branch
  Future<List<QueueModel>> getTodayQueue(String branchId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
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
        .gte('created_at', '${today}T00:00:00')
        .lte('created_at', '${today}T23:59:59')
        .neq('status', 'cancelled')
        .order('queue_number', ascending: true);

    return response.map((j) => QueueModel.fromJson(j)).toList();
  }

  // Get queue entry for customer's appointment
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

  // Update queue status
  Future<void> updateQueueStatus(String id, String status) async {
    final Map<String, dynamic> updates = {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    switch (status) {
      case 'in_progress':
        updates['start_service_time'] = DateTime.now().toIso8601String();
        updates['called_time'] = DateTime.now().toIso8601String();
        break;
      case 'completed':
        updates['end_service_time'] = DateTime.now().toIso8601String();
        break;
    }

    await _client
        .from(SupabaseConfig.queueTable)
        .update(updates)
        .eq('id', id);

    // Also update related appointment
    if (status == 'in_progress' || status == 'completed') {
      final queue = await _client
          .from(SupabaseConfig.queueTable)
          .select('appointment_id')
          .eq('id', id)
          .single();

      if (queue['appointment_id'] != null) {
        final aptStatus = status == 'in_progress' ? 'in_progress' : 'completed';
        await _client
            .from(SupabaseConfig.appointmentsTable)
            .update({'status': aptStatus})
            .eq('id', queue['appointment_id'] as String);
      }
    }
  }

  // Add walk-in to queue
  Future<QueueModel> addWalkIn({
    required String branchId,
    required String serviceId,
    String? barberId,
    String? customerName,
  }) async {
    // Create walk-in appointment first
    final serviceData = await _client
        .from(SupabaseConfig.servicesTable)
        .select('price, duration_minutes')
        .eq('id', serviceId)
        .single();

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Get today's queue count
    final today = now.toIso8601String().split('T').first;
    final queueData = await _client
        .from(SupabaseConfig.queueTable)
        .select('queue_number')
        .eq('branch_id', branchId)
        .gte('created_at', '${today}T00:00:00')
        .order('queue_number', ascending: false)
        .limit(1);

    final maxNumber =
        queueData.isEmpty ? 0 : (queueData.first['queue_number'] as int);

    // Insert appointment
    final aptResponse = await _client
        .from(SupabaseConfig.appointmentsTable)
        .insert({
          'branch_id': branchId,
          'service_id': serviceId,
          'barber_id': barberId,
          'appointment_date': today,
          'appointment_time': timeStr,
          'total_price': (serviceData['price'] as num).toDouble(),
          'is_walk_in': true,
          'status': 'confirmed',
        })
        .select('id')
        .single();

    final queueResponse = await _client
        .from(SupabaseConfig.queueTable)
        .insert({
          'appointment_id': aptResponse['id'] as String,
          'branch_id': branchId,
          'queue_number': maxNumber + 1,
          'status': 'waiting',
          'estimated_wait_minutes': (maxNumber + 1) * 30,
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

  // Realtime stream for queue
  Stream<List<Map<String, dynamic>>> watchQueue(String branchId) {
    return _client
        .from(SupabaseConfig.queueTable)
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .order('queue_number', ascending: true);
  }

  // Get queue stats
  Future<Map<String, int>> getQueueStats(String branchId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final response = await _client
        .from(SupabaseConfig.queueTable)
        .select('status')
        .eq('branch_id', branchId)
        .gte('created_at', '${today}T00:00:00');

    final stats = <String, int>{
      'total': response.length,
      'waiting': 0,
      'in_progress': 0,
      'completed': 0,
    };

    for (final item in response) {
      final s = item['status'] as String;
      stats[s] = (stats[s] ?? 0) + 1;
    }

    return stats;
  }
}