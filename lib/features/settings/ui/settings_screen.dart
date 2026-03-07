import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../data/services/backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _storeNameCtrl;

  @override
  void initState() {
    super.initState();
    _storeNameCtrl = TextEditingController(
        text: ref.read(settingsProvider).storeName);
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ─── Store Info ─────────────────────────────────────────────────────
          _SectionHeader('Store'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _storeNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Store Name',
                      hintText: 'e.g. Aling Nena\'s Store',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .setStoreName(_storeNameCtrl.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Store name saved')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),

          // ─── Features ───────────────────────────────────────────────────────
          _SectionHeader('Features'),
          SwitchListTile(
            secondary: const Icon(Icons.money_off_outlined),
            title: const Text('Allow Overpayment'),
            subtitle: const Text('Let balance go negative (advance payment)'),
            value: settings.allowNegativeBalance,
            onChanged: (v) => ref
                .read(settingsNotifierProvider.notifier)
                .toggleNegativeBalance(v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.camera_alt_outlined),
            title: const Text('Transaction Photos'),
            subtitle: const Text('Optionally capture photo during checkout'),
            value: settings.enableTransactionPhotos,
            onChanged: (v) => ref
                .read(settingsNotifierProvider.notifier)
                .toggleTransactionPhotos(v),
          ),

          _SectionHeader('Backup & Restore'),
          ListTile(
            leading: const Icon(Icons.backup_outlined, color: Colors.blue),
            title: const Text('Backup Database'),
            subtitle: const Text('Save a copy to Downloads folder'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _doBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined, color: Colors.orange),
            title: const Text('Restore from Backup'),
            subtitle: const Text('⚠️ Current data will be replaced'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRestoreWarning(context),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined, color: Colors.green),
            title: const Text('Export Products CSV'),
            subtitle: const Text('Export product list as spreadsheet'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportCsv(context, ref),
          ),

          // ─── About ──────────────────────────────────────────────────────────
          _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Sari POS'),
            subtitle: Text('Version 1.0.0 · 100% Offline · Made for sari-sari stores'),
          ),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Database'),
            subtitle: Text('SQLite (Drift) · All data stored on this device'),
          ),
          const ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Product Images'),
            subtitle: Text('Powered by Open Food Facts · CC BY-SA 3.0'),
          ),
        ],
      ),
    );
  }

  Future<void> _doBackup(BuildContext context) async {
    try {
      final path = await BackupService.backup();
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Backup Complete'),
            content: Text('Database backed up to:\n\n$path'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showRestoreWarning(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text(
          '⚠️ This will REPLACE all current data with the backup.\n\n'
          'Make sure to backup first before restoring.\n\n'
          'The app will close after restoring — please reopen it manually.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'To restore: copy your .sqlite backup file to the app folder then call BackupService.restore(path)'),
                ),
              );
            },
            child: const Text('I Understand'),
          ),
        ],
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
          SnackBar(content: Text('CSV exported to: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Export failed: $e'),
                backgroundColor: Colors.red));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}