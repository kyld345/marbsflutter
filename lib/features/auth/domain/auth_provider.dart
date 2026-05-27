// lib/features/auth/domain/auth_provider.dart
// FIXED:
//  1. Added adminCreationInProgressProvider — suppresses router redirect
//     while admin is creating a barber account (prevents the admin from being
//     kicked to dashboard when signUp() fires an auth state change).
//  2. AuthNotifier.signUp() now signs out immediately after creating the
//     account so the new user is NOT auto-logged in.  Without this, the auth
//     state change from signUp() triggers a router redirect to /home before
//     register_screen can navigate to /login.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

// ============================================================
// ADMIN CREATION LOCK
// When true, the router redirect is suppressed so that the
// auth state change triggered by signUp() during barber account
// creation doesn't kick the admin out of the barbers page.
// ============================================================
final adminCreationInProgressProvider = StateProvider<bool>((ref) => false);

// Auth state stream — emits null when logged out
final authStateProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges.map((event) => event.session?.user);
});

// Current user profile
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return null;
  final repository = ref.watch(authRepositoryProvider);
  return repository.getUserProfile(authState.id);
});

// ============================================================
// USER ROLE PROVIDER
// Uses DB lookup only (not metadata), with retry logic.
// authStateProvider drives rebuild so re-fetches on login/logout.
// ============================================================
final userRoleAsyncProvider = FutureProvider<String>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return 'customer';

  final repository = ref.watch(authRepositoryProvider);

  // Retry up to 3 times with backoff (handles trigger timing)
  String? dbRole;
  for (int attempt = 0; attempt < 3; attempt++) {
    dbRole = await repository.getUserRole(authUser.id);
    if (dbRole != null && dbRole.isNotEmpty) break;
    if (attempt < 2) {
      await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
  }

  if (dbRole != null && dbRole.isNotEmpty) {
    return dbRole.trim().toLowerCase();
  }

  return 'customer';
});

// Sync role provider — returns 'customer' while loading
final userRoleProvider = Provider<String>((ref) {
  return ref.watch(userRoleAsyncProvider).value ?? 'customer';
});

// ============================================================
// ROUTER REFRESH NOTIFIER
// Router is created ONCE; this notifier triggers re-evaluation
// of redirects when auth/role state changes.
// ============================================================
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) {
      notifyListeners();
    });
    ref.listen<AsyncValue<String>>(userRoleAsyncProvider, (prev, next) {
      notifyListeners();
    });
  }
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

// ============================================================
// AUTH NOTIFIER — handles sign in / sign up / sign out
// ============================================================
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<bool> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signIn(email: email, password: password);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: 'customer',
      );

      // FIX: Sign out immediately after signup so the user is NOT
      // auto-logged in.  Without this, the auth state change from signUp()
      // triggers a router redirect to /home (customer dashboard) BEFORE
      // register_screen.dart can call context.go('/login').
      // The user should verify their email and sign in manually.
      try {
        await _repository.signOut();
      } catch (_) {
        // Ignore sign-out errors — account was created successfully
      }

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<bool> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _repository.resetPassword(email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
