import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db/app_database.dart';
import '../data/services/image_storage_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final imageStorageProvider =
    Provider<ImageStorageService>((_) => ImageStorageService());

// ─── App Settings ────────────────────────────────────────────────────────────

class AppSettings {
  final String storeName;
  final String? storeAddress;
  final bool allowNegativeBalance;
  final bool enableTransactionPhotos;

  const AppSettings({
    this.storeName = 'My Sari-sari Store',
    this.storeAddress,
    this.allowNegativeBalance = false,
    this.enableTransactionPhotos = false,
  });

  AppSettings copyWith({String? storeName, String? storeAddress, bool? allowNegativeBalance, bool? enableTransactionPhotos}) =>
      AppSettings(
        storeName: storeName ?? this.storeName,
        storeAddress: storeAddress ?? this.storeAddress,
        allowNegativeBalance: allowNegativeBalance ?? this.allowNegativeBalance,
        enableTransactionPhotos: enableTransactionPhotos ?? this.enableTransactionPhotos,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setStoreName(String name) {
    if (name.trim().isEmpty) return; // Don't allow empty store name
    state = state.copyWith(storeName: name.trim());
  }

  void setStoreAddress(String address) {
    state = state.copyWith(storeAddress: address.trim().isEmpty ? null : address.trim());
  }

  void toggleNegativeBalance(bool allow) {
    state = state.copyWith(allowNegativeBalance: allow);
  }

  void toggleTransactionPhotos(bool enable) {
    state = state.copyWith(enableTransactionPhotos: enable);
  }
}

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
        (_) => SettingsNotifier());

// Convenience read
final settingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsNotifierProvider);
});