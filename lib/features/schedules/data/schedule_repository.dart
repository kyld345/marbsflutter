// lib/features/schedules/data/schedule_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/schedule_model.dart';
import '../../../core/config/supabase_config.dart';

class ScheduleRepository {
  final SupabaseClient _client;
  ScheduleRepository(this._client);

  Future<List<ScheduleModel>> getSchedules({String? barberId}) async {
    var query = _client
        .from(SupabaseConfig.schedulesTable)
        .select('*, barbers!barber_id(*, users(full_name))');
    if (barberId != null) query = query.eq('barber_id', barberId);
    final response = await query.order('barber_id').order('day_of_week');
    return response.map((j) => ScheduleModel.fromJson(j)).toList();
  }

  Future<void> upsertSchedule({
    required String barberId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    bool isDayOff = false,
  }) async {
    await _client.from(SupabaseConfig.schedulesTable).upsert(
      {
        'barber_id': barberId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'is_day_off': isDayOff,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'barber_id,day_of_week',
    );
  }

  Future<void> deleteSchedule(String id) async {
    await _client.from(SupabaseConfig.schedulesTable).delete().eq('id', id);
  }
}