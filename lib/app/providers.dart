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
  final bool allowNegativeBalance;

  const AppSettings({
    this.storeName = 'My Sari-sari Store',
    this.allowNegativeBalance = false,
  });

  AppSettings copyWith({String? storeName, bool? allowNegativeBalance}) =>
      AppSettings(
        storeName: storeName ?? this.storeName,
        allowNegativeBalance: allowNegativeBalance ?? this.allowNegativeBalance,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setStoreName(String name) {
    state = state.copyWith(storeName: name.trim().isEmpty ? 'My Sari-sari Store' : name.trim());
  }

  void toggleNegativeBalance(bool allow) {
    state = state.copyWith(allowNegativeBalance: allow);
  }
}

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
        (_) => SettingsNotifier());

// Convenience read
final settingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsNotifierProvider);
});