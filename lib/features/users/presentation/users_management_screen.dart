// lib/features/users/presentation/users_management_screen.dart
// ADMIN ONLY: View all users, assign/change roles via admin_set_user_role()

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/common_widgets.dart';

// ────────────────────────────────────────────────────────────
// Providers
// ────────────────────────────────────────────────────────────

final usersListProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String?>(
        (ref, roleFilter) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getUsersList(roleFilter: roleFilter);
});

final rolesListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getRolesList();
});

// ────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState
    extends ConsumerState<UsersManagementScreen> {
  String? _selectedRoleFilter;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider(_selectedRoleFilter));
    final rolesAsync = ref.watch(rolesListProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Management',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            Text('Assign and manage user roles',
                style:
                    GoogleFonts.dmSans(color: AppTheme.textHint, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usersListProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search + filter bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.dmSans(
                        color: AppTheme.textPrimary, fontSize: 14),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textHint, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppTheme.textHint, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Role filter
                rolesAsync.when(
                  data: (roles) => DropdownButton<String?>(
                    value: _selectedRoleFilter,
                    hint: Text('All Roles',
                        style: GoogleFonts.dmSans(
                            color: AppTheme.textHint, fontSize: 13)),
                    dropdownColor: AppTheme.cardColor,
                    style: GoogleFonts.dmSans(
                        color: AppTheme.textPrimary, fontSize: 13),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.filter_list,
                        color: AppTheme.textHint, size: 20),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Roles'),
                      ),
                      ...roles.map((r) => DropdownMenuItem<String?>(
                            value: r['name'] as String,
                            child: Text(
                                (r['name'] as String).toUpperCase()),
                          )),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedRoleFilter = v),
                  ),
                  loading: () => const SizedBox(width: 40),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: usersAsync.when(
              data: (users) {
                // Apply search filter
                final filtered = _searchQuery.isEmpty
                    ? users
                    : users.where((u) {
                        final name =
                            (u['full_name'] as String? ?? '').toLowerCase();
                        final email = (u['email'] as String? ?? '').toLowerCase();
                        final q = _searchQuery.toLowerCase();
                        return name.contains(q) || email.contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline,
                            color: AppTheme.textHint, size: 56),
                        const SizedBox(height: 12),
                        Text('No users found',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.textHint, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _UserTile(
                    user: filtered[i],
                    onRoleChanged: (userId, newRole) =>
                        _handleRoleChange(userId, newRole),
                  ).animate().fadeIn(
                      delay: Duration(milliseconds: i * 40),
                      duration: 300.ms),
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.error, size: 48),
                    const SizedBox(height: 12),
                    Text('Error loading users',
                        style: GoogleFonts.dmSans(color: AppTheme.error)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(usersListProvider),
                      child: const Text('Retry',
                          style: TextStyle(color: AppTheme.secondary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRoleChange(String userId, String newRole) async {
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.adminSetUserRole(
          targetUserId: userId, roleName: newRole);
      ref.invalidate(usersListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Role updated to ${newRole.toUpperCase()}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ────────────────────────────────────────────────────────────
// User tile
// ────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final void Function(String userId, String newRole) onRoleChanged;

  const _UserTile({required this.user, required this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    final name = user['full_name'] as String? ?? 'Unknown';
    final email = user['email'] as String? ?? '';
    final phone = user['phone'] as String? ?? '';
    final isActive = user['is_active'] as bool? ?? true;
    final createdAt = user['created_at'] as String?;
    final roleData = user['roles'];
    final currentRole = roleData is Map
        ? roleData['name'] as String? ?? 'customer'
        : 'customer';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF1E2A3A)
              : AppTheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: _roleColor(currentRole).withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.playfairDisplay(
                color: _roleColor(currentRole),
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Inactive',
                            style: GoogleFonts.dmSans(
                                color: AppTheme.error, fontSize: 10)),
                      ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 12)),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(phone,
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textHint, fontSize: 12)),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Joined ${_formatDate(createdAt)}',
                    style: GoogleFonts.dmSans(
                        color: AppTheme.textHint, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Role assignment dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _roleColor(currentRole).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _roleColor(currentRole).withValues(alpha: 0.4)),
                ),
                child: Text(
                  currentRole.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    color: _roleColor(currentRole),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PopupMenuButton<String>(
                tooltip: 'Change Role',
                color: AppTheme.cardColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (role) =>
                    onRoleChanged(user['id'] as String, role),
                itemBuilder: (ctx) => [
                  'customer',
                  'barber',
                  'receptionist',
                  'admin'
                ]
                    .map((role) => PopupMenuItem<String>(
                          value: role,
                          child: Row(
                            children: [
                              Icon(
                                _roleIcon(role),
                                color: _roleColor(role),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                role.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  color: currentRole == role
                                      ? _roleColor(role)
                                      : AppTheme.textPrimary,
                                  fontWeight: currentRole == role
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                              if (currentRole == role) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.check,
                                    color: _roleColor(role), size: 14),
                              ],
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFF37474F)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Change Role',
                          style: GoogleFonts.dmSans(
                              color: AppTheme.textSecondary,
                              fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more,
                          color: AppTheme.textHint, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin': return AppTheme.secondary;
      case 'receptionist': return AppTheme.info;
      case 'barber': return Colors.purple;
      default: return AppTheme.success;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings;
      case 'receptionist': return Icons.support_agent;
      case 'barber': return Icons.content_cut;
      default: return Icons.person;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM d, y').format(dt);
    } catch (_) {
      return iso;
    }
  }
}