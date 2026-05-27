// lib/features/notifications/presentation/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/notification_provider.dart';
import '../domain/notification_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';
import '../../auth/domain/auth_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Notifications',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700)),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () {
                ref
                    .read(notificationNotifierProvider.notifier)
                    .markAllAsRead(user.id);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              },
              child: Text('Mark all read',
                  style: GoogleFonts.dmSans(
                      color: AppTheme.secondary, fontSize: 13)),
            ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none,
                      size: 80, color: AppTheme.textHint),
                  const SizedBox(height: 16),
                  Text('No notifications',
                      style: GoogleFonts.playfairDisplay(
                          color: AppTheme.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text("You're all caught up!",
                      style: GoogleFonts.dmSans(color: AppTheme.textHint)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (_, index) => _buildNotificationTile(
                context, ref, notifications[index], index),
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(error: e.toString()),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
    int index,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(notificationNotifierProvider.notifier).delete(notification.id);
      },
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            ref
                .read(notificationNotifierProvider.notifier)
                .markAsRead(notification.id);
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? AppTheme.cardColor
                : AppTheme.secondary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: notification.isRead
                ? null
                : Border.all(
                    color: AppTheme.secondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getTypeColor(notification.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(notification.type),
                  color: _getTypeColor(notification.type),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.timeAgo,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (index * 40).ms),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'appointment':
        return AppTheme.info;
      case 'queue':
        return AppTheme.warning;
      case 'promotion':
        return AppTheme.secondary;
      default:
        return AppTheme.textHint;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'appointment':
        return Icons.calendar_today_outlined;
      case 'queue':
        return Icons.queue_outlined;
      case 'promotion':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
