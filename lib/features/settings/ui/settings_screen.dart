import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../data/services/backup_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/auth/ui/login_screen.dart';
import '../../../features/auth/ui/account_screen.dart';
import '../../../features/auth/ui/upgrade_screen.dart';
import 'feedback_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Cloud Account Card
          _buildCloudAccountCard(context),

          const SizedBox(height: 16),

          // Store Info Card
          _buildCard(
            title: 'Store Information',
            icon: Icons.store_outlined,
            iconColor: AppTheme.primary,
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.edit_outlined,
                  iconColor: AppTheme.primary,
                  title: 'Store Details',
                  subtitle: settings.storeName.isEmpty 
                      ? 'Set your store name and address'
                      : settings.storeName,
                  onTap: () => _showStoreDetailsDialog(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Features Card
          _buildCard(
            title: 'Features',
            icon: Icons.tune_outlined,
            iconColor: Colors.blue,
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.money_off_outlined,
                  title: 'Allow Overpayment',
                  subtitle: 'Let balance go negative (advance payment)',
                  value: settings.allowNegativeBalance,
                  onChanged: (v) => ref
                      .read(settingsNotifierProvider.notifier)
                      .toggleNegativeBalance(v),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _buildSwitchTile(
                  icon: Icons.camera_alt_outlined,
                  title: 'Transaction Photos',
                  subtitle: 'Capture photo during checkout',
                  value: settings.enableTransactionPhotos,
                  onChanged: (v) => ref
                      .read(settingsNotifierProvider.notifier)
                      .toggleTransactionPhotos(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Data Management Card
          _buildCard(
            title: 'Data Management',
            icon: Icons.folder_outlined,
            iconColor: Colors.orange,
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.backup_outlined,
                  iconColor: Colors.blue,
                  title: 'Backup Database',
                  subtitle: 'Save a copy to Downloads',
                  onTap: () => _doBackup(context),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _buildActionTile(
                  icon: Icons.restore_outlined,
                  iconColor: Colors.orange,
                  title: 'Restore from Backup',
                  subtitle: 'Current data will be replaced',
                  onTap: () => _showRestoreWarning(context),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _buildActionTile(
                  icon: Icons.table_chart_outlined,
                  iconColor: Colors.green,
                  title: 'Export Products CSV',
                  subtitle: 'Export as spreadsheet',
                  onTap: () => _exportCsv(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Support & Feedback Card
          _buildCard(
            title: 'Support & Feedback',
            icon: Icons.support_agent_outlined,
            iconColor: Colors.teal,
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.feedback_outlined,
                  iconColor: Colors.teal,
                  title: 'Send Feedback',
                  subtitle: 'Report bugs, request features, or share suggestions',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _buildActionTile(
                  icon: Icons.help_outline,
                  iconColor: Colors.blue,
                  title: 'Help & Support',
                  subtitle: 'Get help with using the app',
                  onTap: () => _showHelpDialog(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About Card
          _buildCard(
            title: 'About',
            icon: Icons.info_outline,
            iconColor: Colors.purple,
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.storefront,
                  title: 'TindaKo',
                  subtitle: 'Version 1.0.0',
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _buildInfoTile(
                  icon: Icons.code_outlined,
                  title: 'Developer',
                  subtitle: 'Hasim Tordios · htordios@gmail.com',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCloudAccountCard(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final user = ref.watch(currentUserProvider);
    final premiumAsync = ref.watch(isPremiumProvider);

    // Determine destination on tap
    Widget destination() {
      if (!isLoggedIn) return const LoginScreen();
      return premiumAsync.maybeWhen(
        data: (isPremium) =>
            isPremium ? const AccountScreen() : const UpgradeScreen(),
        orElse: () => const AccountScreen(),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => destination(),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoggedIn
                ? [const Color(0xFF2D5F3F), const Color(0xFF4A8B5C)]
                : [Colors.grey.shade700, Colors.grey.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isLoggedIn ? AppTheme.primary : Colors.grey)
                  .withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isLoggedIn
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoggedIn ? 'Cloud Account' : 'Enable Cloud Sync',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isLoggedIn
                        ? user?.email ?? ''
                        : 'Login or register to back up your data',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.85)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(height: 4),
                    premiumAsync.when(
                      data: (isPremium) => Text(
                        isPremium ? '✓ Premium · Sync Active' : 'Free · Sync Locked',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.75)),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.7), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStoreDetailsDialog(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final nameCtrl = TextEditingController(text: settings.storeName);
    final addressCtrl = TextEditingController(text: settings.storeAddress ?? '');

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.store, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Store Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Store Name *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Enter store name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Address (Optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: addressCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter store address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.error, color: Colors.white, size: 20),
                                        const SizedBox(width: 12),
                                        Text('Store name is required'),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                                return;
                              }
                              
                              ref.read(settingsNotifierProvider.notifier).setStoreName(name);
                              ref.read(settingsNotifierProvider.notifier).setStoreAddress(addressCtrl.text.trim());
                              
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                                      const SizedBox(width: 12),
                                      Text('Store details saved'),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF2E7D32),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doBackup(BuildContext context) async {
    try {
      final path = await BackupService.backup();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              color: Colors.white,
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Backup Complete',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Database backed up to:\n\n$path',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('OK'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Backup failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showRestoreWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Restore Database',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This will REPLACE all current data with the backup.\n\nMake sure to backup first before restoring.\n\nThe app will close after restoring — please reopen it manually.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'To restore: copy your .sqlite backup file to the app folder then call BackupService.restore(path)',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            },
                            child: const Text('I Understand'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final products = await db.productsDao.getAllProducts();
      final categories = await db.productsDao.getAllCategories();
      final catMap = {for (final c in categories) c.id: c.name};

      final rows = products
          .map((p) => {
                'name': p.name,
                'category': catMap[p.categoryId] ?? '',
                'price': (p.priceCents / 100).toStringAsFixed(2),
                'cost': p.costCents != null
                    ? (p.costCents! / 100).toStringAsFixed(2)
                    : '',
                'stock': p.stockQty.toString(),
                'unit': p.unit,
                'barcode': p.barcode ?? '',
                'active': p.isActive ? 'Yes' : 'No',
              })
          .toList();

      final path = await BackupService.exportProductsCsv(rows);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('CSV exported to: $path')),
              ],
            ),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Export failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          color: Colors.white,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.help_outline, color: Colors.blue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Help & Support',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildHelpItem(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Making Sales',
                      description: 'Go to POS tab → Select products → Choose payment method',
                    ),
                    const SizedBox(height: 16),
                    _buildHelpItem(
                      icon: Icons.inventory_outlined,
                      title: 'Managing Products',
                      description: 'Products tab → Add/Edit products → Set prices & stock',
                    ),
                    const SizedBox(height: 16),
                    _buildHelpItem(
                      icon: Icons.people_outline,
                      title: 'Customer Credit (Utang)',
                      description: 'Utang tab → Add customers → Record payments',
                    ),
                    const SizedBox(height: 16),
                    _buildHelpItem(
                      icon: Icons.assessment_outlined,
                      title: 'Viewing Reports',
                      description: 'Reports tab → Select time period → View sales data',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
