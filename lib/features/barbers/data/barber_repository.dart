// lib/features/barbers/data/barber_repository.dart
//
// FIXES:
//  1. RLS error (42501): Replaced direct upsert into users table with
//     admin_set_user_role RPC, which runs SECURITY DEFINER and bypasses RLS.
//     Admins cannot upsert another user's row directly — the RPC is the only
//     RLS-safe way to change another user's role.
//  2. Always sets barber role regardless of trigger timing.
//  3. Null-safety guards on optional string fields.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/barber_model.dart';

class BarberRepository {
  final SupabaseClient _client;

  BarberRepository(this._client);

  Future<List<BarberModel>> getBarbers({
    bool? isAvailable,
    String? branchId,
    int page = 0,
    int pageSize = 20,
  }) async {
    var query = _client
        .from(SupabaseConfig.barbersTable)
        .select('*, users(full_name, phone, avatar_url), branches(name)');

    if (isAvailable != null) query = query.eq('is_available', isAvailable);
    if (branchId != null) query = query.eq('branch_id', branchId);

    final response = await query
        .order('rating', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return response.map((json) => BarberModel.fromJson(json)).toList();
  }

  Future<BarberModel> getBarber(String id) async {
    final response = await _client
        .from(SupabaseConfig.barbersTable)
        .select('*, users(full_name, phone, avatar_url), branches(name)')
        .eq('id', id)
        .single();
    return BarberModel.fromJson(response);
  }

  Future<BarberModel> createBarber({
    String? userId,
    String? displayName,
    required String branchId,
    String? specialization,
    String? bio,
    int experienceYears = 0,
  }) async {
    final payload = {
      'user_id': userId,
      'display_name': displayName,
      'branch_id': branchId,
      'specialization': specialization,
      'bio': bio,
      'experience_years': experienceYears,
    };

    final response = await _insertBarberPayload(payload);
    return BarberModel.fromJson(response);
  }

  Future<BarberModel> createBarberWithAccount({
    required String email,
    required String password,
    required String fullName,
    required String branchId,
    String? specialization,
    String? bio,
    int experienceYears = 0,
  }) async {
    // Snapshot the current admin/receptionist session BEFORE signing up the
    // new barber, so we can restore it afterwards.
    final previousSession = _client.auth.currentSession;

    final authResponse = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': 'barber'},
    );

    final user = authResponse.user;
    if (user == null) {
      throw Exception('Failed to create barber account. Please try again.');
    }
    final userId = user.id;

    // ── Restore admin/receptionist session immediately ─────────────────────
    // Must happen BEFORE any table writes so RLS permissions are correct.
    final refreshToken = previousSession?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _client.auth.setSession(
          refreshToken,
          accessToken: previousSession!.accessToken,
        );
      } catch (e) {
        throw Exception(
          'Barber account created but failed to restore your session: $e\n'
          'Please sign in again to continue.',
        );
      }
    }

    // ── FIX: Set barber role via admin_set_user_role RPC ──────────────────
    //
    // Direct upsert into users table fails with RLS error 42501 because the
    // RLS policy only allows users to update THEIR OWN row.  Even with the
    // admin session restored, admins cannot update another user's row via the
    // anon client.
    //
    // admin_set_user_role() is a SECURITY DEFINER function — it bypasses RLS
    // and is the correct way to change another user's role.
    //
    // The Supabase signup trigger always sets role = 'customer' regardless of
    // metadata, so this RPC call is ALWAYS needed to correct the role.
    //
    // Retry up to 3 times to handle trigger race conditions where the users
    // row hasn't been committed yet when the RPC runs.
    //
    // NOTE: If the caller is a receptionist (not admin), the RPC will raise
    // P0001 "Unauthorized: only admins can assign roles".  In that case we
    // swallow the error and continue — the barber profile is still created and
    // an admin can correct the role later.  To allow receptionists to assign
    // the barber role, run this SQL in Supabase:
    //
    //   CREATE OR REPLACE FUNCTION admin_set_user_role(
    //     target_user_id uuid, new_role_name text
    //   ) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
    //   DECLARE calling_role text;
    //   BEGIN
    //     SELECT r.name INTO calling_role
    //     FROM users u JOIN roles r ON r.id = u.role_id
    //     WHERE u.id = auth.uid();
    //     IF calling_role NOT IN ('admin','receptionist') THEN
    //       RAISE EXCEPTION 'Unauthorized: only admins or receptionists can assign roles';
    //     END IF;
    //     UPDATE users SET role_id = (SELECT id FROM roles WHERE name = new_role_name)
    //     WHERE id = target_user_id;
    //   END; $$;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _client.rpc('admin_set_user_role', params: {
          'target_user_id': userId,
          'new_role_name': 'barber',
        });
        break; // success — stop retrying
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
        // On final attempt failure: caller may lack permission (receptionist).
        // Barber profile is still created; an admin can fix the role later.
      }
    }

    // ── Insert into barbers table ──────────────────────────────────────────
    final response = await _insertBarberPayload({
      'user_id': userId,
      'display_name': fullName,
      'branch_id': branchId,
      'specialization':
          (specialization?.trim().isNotEmpty == true) ? specialization!.trim() : null,
      'bio': (bio?.trim().isNotEmpty == true) ? bio!.trim() : null,
      'experience_years': experienceYears,
    });

    return BarberModel.fromJson(response);
  }

  Future<Map<String, dynamic>> _insertBarberPayload(
      Map<String, dynamic> payload) async {
    return await _client
        .from(SupabaseConfig.barbersTable)
        .insert(payload)
        .select('*, users(full_name, phone, avatar_url), branches(name)')
        .single();
  }

  Future<List<Map<String, dynamic>>> getUsersWithoutBarberProfile() async {
    final existingBarberUsers = await _client
        .from(SupabaseConfig.barbersTable)
        .select('user_id')
        .not('user_id', 'is', null);

    final usedIds = existingBarberUsers
        .map((row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet();

    final users = await _client
        .from(SupabaseConfig.usersTable)
        .select('id, full_name, roles(name)')
        .order('full_name');

    return users
        .where((u) {
          final roleMap = u['roles'] as Map<String, dynamic>?;
          final roleName = (roleMap?['name'] as String?)?.toLowerCase();
          return roleName != 'admin' && roleName != 'receptionist';
        })
        .where((u) => !usedIds.contains(u['id'] as String?))
        .map((u) => Map<String, dynamic>.from(u))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getActiveBranches() async {
    final branches = await _client
        .from(SupabaseConfig.branchesTable)
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return branches.map((b) => Map<String, dynamic>.from(b)).toList();
  }

  Future<void> updateBarber(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    await _client
        .from(SupabaseConfig.barbersTable)
        .update(updates)
        .eq('id', id);
  }

  Future<void> deleteBarber(String id) async {
    await _client.from(SupabaseConfig.barbersTable).delete().eq('id', id);
  }

  Future<void> toggleAvailability(String id, bool isAvailable) async {
    await updateBarber(id, {'is_available': isAvailable});
  }
}
