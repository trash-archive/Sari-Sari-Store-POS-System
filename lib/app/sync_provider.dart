import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../features/auth/auth_provider.dart';
import '../data/services/sync/sync_service.dart';

export '../data/services/sync/sync_service.dart' show SyncResult;

// ── Sync Service instance ────────────────────────────────────

final syncServiceProvider = Provider<SyncService?>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return null;
  return SyncService(
    ref.watch(databaseProvider),
    ref.watch(supabaseProvider),
  );
});

// ── Sync state ───────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final SyncResult? lastResult;

  const SyncState({this.status = SyncStatus.idle, this.lastResult});

  SyncState copyWith({SyncStatus? status, SyncResult? lastResult}) =>
      SyncState(
        status: status ?? this.status,
        lastResult: lastResult ?? this.lastResult,
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;

  SyncNotifier(this._ref) : super(const SyncState());

  Future<void> sync() async {
    final service = _ref.read(syncServiceProvider);
    if (service == null) return; // not logged in

    // Check premium before syncing
    final isPremium = await _ref.read(isPremiumProvider.future);
    if (!isPremium) return;

    state = state.copyWith(status: SyncStatus.syncing);
    final result = await service.sync();
    state = SyncState(
      status: result.success ? SyncStatus.success : SyncStatus.error,
      lastResult: result,
    );
  }

  /// Called silently after each transaction — no UI feedback needed.
  Future<void> syncQuiet() async {
    final service = _ref.read(syncServiceProvider);
    if (service == null) return;
    final isPremium = await _ref.read(isPremiumProvider.future);
    if (!isPremium) return;
    await service.sync();
  }
}

final syncNotifierProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});
