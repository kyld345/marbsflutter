// lib/features/notifications/data/notification_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/notification_model.dart';
import '../../../core/config/supabase_config.dart';

class NotificationRepository {
  final SupabaseClient _client;
  NotificationRepository(this._client);

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final response = await _client
        .from(SupabaseConfig.notificationsTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return response.map((j) => NotificationModel.fromJson(j)).toList();
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _client
        .from(SupabaseConfig.notificationsTable)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return response.length;
  }

  Future<void> markAsRead(String id) async {
    await _client
        .from(SupabaseConfig.notificationsTable)
        .update({'is_read': true})
        .eq('id', id);
  }

  Future<void> markAllAsRead(String userId) async {
    await _client
        .from(SupabaseConfig.notificationsTable)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String id) async {
    await _client
        .from(SupabaseConfig.notificationsTable)
        .delete()
        .eq('id', id);
  }

  Stream<List<Map<String, dynamic>>> watchNotifications(String userId) {
    return _client
        .from(SupabaseConfig.notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(20);
  }
}