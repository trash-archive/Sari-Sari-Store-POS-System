import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream of connectivity results — rebuilds whenever network changes.
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Simple bool: true when at least one non-none connection is active.
final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).maybeWhen(
        data: (results) =>
            results.any((r) => r != ConnectivityResult.none),
        orElse: () => true, // assume online until proven otherwise
      );
});
