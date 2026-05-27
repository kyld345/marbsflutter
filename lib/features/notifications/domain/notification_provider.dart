// lib/features/notifications/domain/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';
import '../../auth/domain/auth_provider.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotificationRepository(client);
});

final notificationsProvider =
    StreamProvider<List<NotificationModel>>((ref) async* {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    yield [];
    return;
  }
  final repo = ref.watch(notificationRepositoryProvider);
  yield* repo
      .watchNotifications(user.id)
      .asyncMap((_) => repo.getNotifications(user.id));
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return 0;
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount(user.id);
});

class NotificationNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _repository;
  NotificationNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
  }

  Future<void> markAllAsRead(String userId) async {
    await _repository.markAllAsRead(userId);
  }

  Future<void> delete(String id) async {
    await _repository.deleteNotification(id);
  }
}

final notificationNotifierProvider =
    StateNotifierProvider<NotificationNotifier, AsyncValue<void>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationNotifier(repo);
});