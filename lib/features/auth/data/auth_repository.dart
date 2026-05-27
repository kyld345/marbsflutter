// lib/features/auth/data/auth_repository.dart
// FIXED: Added admin_set_user_role, getUsersList for admin

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String role = 'customer', // NOTE: schema trigger ignores this for security
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
      },
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.usersTable)
          .select('*, roles(name)')
          .eq('id', userId)
          .single();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Deterministic role lookup: users.role_id → roles.name
  Future<String?> getUserRole(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.usersTable)
          .select('roles(name)')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      final roleData = response['roles'];
      if (roleData is Map) {
        return roleData['name'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    updates['updated_at'] = DateTime.now().toIso8601String();

    await _client
        .from(SupabaseConfig.usersTable)
        .update(updates)
        .eq('id', userId);
  }

  /// Admin-only: Assign a role to a user via secure DB function
  Future<void> adminSetUserRole({
    required String targetUserId,
    required String roleName,
  }) async {
    await _client.rpc('admin_set_user_role', params: {
      'target_user_id': targetUserId,
      'new_role_name': roleName,
    });
  }

  /// Admin/Receptionist: List all users with their roles
  Future<List<Map<String, dynamic>>> getUsersList({
    int limit = 50,
    int offset = 0,
    String? roleFilter,
  }) async {
    var query = _client
        .from(SupabaseConfig.usersTable)
        .select('*, roles(id, name)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (roleFilter != null && roleFilter.isNotEmpty) {
      // Filter by role name via joined table
      // We do client-side filter after fetch
    }

    final data = await query;
    final users = List<Map<String, dynamic>>.from(data);

    if (roleFilter != null && roleFilter.isNotEmpty) {
      return users.where((u) {
        final role = u['roles'];
        if (role is Map) return role['name'] == roleFilter;
        return false;
      }).toList();
    }

    return users;
  }

  Future<List<Map<String, dynamic>>> getRolesList() async {
    final data = await _client
        .from(SupabaseConfig.rolesTable)
        .select('id, name, description')
        .order('name');
    return List<Map<String, dynamic>>.from(data);
  }

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}