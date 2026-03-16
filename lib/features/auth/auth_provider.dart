import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ignore: depend_on_referenced_packages
export 'package:supabase_flutter/supabase_flutter.dart' show User, AuthState, AuthChangeEvent;

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

// Streams auth state changes (login, logout, token refresh)
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

// Convenience: current user or null — reactive to auth stream
final currentUserProvider = Provider<User?>((ref) {
  // Watch the stream so this rebuilds on login/logout
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser;
});

// True if user is logged in
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// True if user has paid for cloud sync (premium)
// Cached in SharedPreferences so it works offline and doesn't flicker.
final isPremiumProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  // Try to read cached value first for instant UI
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getBool('is_premium_${user.id}') ?? false;

  // Fetch fresh value from server in background
  try {
    final client = ref.watch(supabaseProvider);
    final data = await client
        .from('profiles')
        .select('is_premium')
        .eq('id', user.id)
        .single();
    final fresh = data['is_premium'] as bool? ?? false;
    await prefs.setBool('is_premium_${user.id}', fresh);
    return fresh;
  } catch (_) {
    // Offline — return cached value
    return cached;
  }
});

class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final SupabaseClient _client;

  AuthNotifier(this._client) : super(const AsyncValue.data(null));

  Future<String?> signUp({
    required String email,
    required String password,
    void Function()? onSuccess,
  }) async {
    state = const AsyncValue.loading();
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      state = const AsyncValue.data(null);
      // If email confirmation is disabled, session is returned immediately
      if (res.session != null) onSuccess?.call();
      return null;
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Something went wrong. Please try again.';
    }
  }

  Future<String?> signIn(
      {required String email,
      required String password,
      void Function()? onSuccess}) async {
    state = const AsyncValue.loading();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      state = const AsyncValue.data(null);
      onSuccess?.call();
      return null;
    } on AuthException catch (e) {
      state = const AsyncValue.data(null);
      return e.message;
    } catch (e) {
      state = const AsyncValue.data(null);
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> signOut() async {
    final user = _client.auth.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_premium_${user.id}');
    }
    await _client.auth.signOut();
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(supabaseProvider));
});
