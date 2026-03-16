import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../app/sync_provider.dart';
import '../auth_provider.dart';
import 'upgrade_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final premiumAsync = ref.watch(isPremiumProvider);
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Cloud Account',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account info card
          _card(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withOpacity(0.12),
                  child: const Icon(Icons.person,
                      color: AppTheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      premiumAsync.when(
                        data: (isPremium) => _PremiumBadge(isPremium),
                        loading: () => const SizedBox(
                            height: 16,
                            width: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Cloud sync status card
          premiumAsync.when(
            data: (isPremium) => _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isPremium
                                  ? AppTheme.primary
                                  : Colors.grey)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isPremium
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          color: isPremium ? AppTheme.primary : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isPremium
                            ? 'Cloud Sync Active'
                            : 'Cloud Sync Locked',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPremium
                        ? 'Your data syncs automatically after each sale. Tap below to sync manually.'
                        : 'Upgrade to premium to enable cloud sync, multi-device access, and tindera sharing.',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  if (isPremium) ...[
                    _SyncButton(syncState: syncState, ref: ref),
                    // Last sync result
                    if (syncState.lastResult != null) ...[
                      const SizedBox(height: 10),
                      _SyncResultRow(result: syncState.lastResult!),
                    ],
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const UpgradeScreen()),
                        ),
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Upgrade to Premium'),
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Logout
          _card(
            child: InkWell(
              onTap: () => _confirmLogout(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout,
                          color: AppTheme.danger, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Logout',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.danger),
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout'),
        content: const Text(
            'Your local data stays on this device. You can log back in anytime.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Logout',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

}

// ── Sync Now button ──────────────────────────────────────────

class _SyncButton extends StatelessWidget {
  final SyncState syncState;
  final WidgetRef ref;

  const _SyncButton({required this.syncState, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isSyncing = syncState.status == SyncStatus.syncing;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSyncing
            ? null
            : () => ref.read(syncNotifierProvider.notifier).sync(),
        icon: isSyncing
            ? const SizedBox(
                width: 16,
                height: 16,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.sync, size: 18),
        label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ── Last sync result row ─────────────────────────────────────

class _SyncResultRow extends StatelessWidget {
  final SyncResult result;
  const _SyncResultRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final isError = !result.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isError ? Colors.red.shade100 : Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isError
                  ? 'Sync failed: ${result.error}'
                  : '↑ ${result.pushed} pushed  ·  ↓ ${result.pulled} pulled',
              style: TextStyle(
                  fontSize: 12,
                  color: isError
                      ? Colors.red.shade700
                      : Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Premium badge ────────────────────────────────────────────

class _PremiumBadge extends StatelessWidget {
  final bool isPremium;
  const _PremiumBadge(this.isPremium);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? AppTheme.primary.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPremium ? Icons.verified : Icons.lock_outline,
            size: 12,
            color: isPremium ? AppTheme.primary : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isPremium ? 'Premium' : 'Free',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPremium ? AppTheme.primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
