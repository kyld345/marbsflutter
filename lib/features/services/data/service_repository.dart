// lib/features/services/data/service_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/service_model.dart';
import '../../../core/config/supabase_config.dart';

class ServiceRepository {
  final SupabaseClient _client;
  ServiceRepository(this._client);

  Future<List<ServiceModel>> getServices({bool? isActive}) async {
    var query = _client.from(SupabaseConfig.servicesTable).select();
    if (isActive != null) query = query.eq('is_active', isActive);
    final response = await query.order('name', ascending: true);
    return response.map((j) => ServiceModel.fromJson(j)).toList();
  }

  Future<ServiceModel> getService(String id) async {
    final response = await _client
        .from(SupabaseConfig.servicesTable)
        .select()
        .eq('id', id)
        .single();
    return ServiceModel.fromJson(response);
  }

  Future<ServiceModel> createService({
    required String name,
    String? description,
    required double price,
    required int durationMinutes,
    String? imageUrl,
  }) async {
    final response = await _client
        .from(SupabaseConfig.servicesTable)
        .insert({
          'name': name,
          'description': description,
          'price': price,
          'duration_minutes': durationMinutes,
          'image_url': imageUrl,
          'is_active': true,
        })
        .select()
        .single();
    return ServiceModel.fromJson(response);
  }

  Future<void> updateService(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client.from(SupabaseConfig.servicesTable).update(updates).eq('id', id);
  }

  Future<void> deleteService(String id) async {
    await _client.from(SupabaseConfig.servicesTable).delete().eq('id', id);
  }

  Future<void> toggleService(String id, bool isActive) async {
    await updateService(id, {'is_active': isActive});
  }
}