import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  /// Get the path of the SQLite DB file
  static Future<String> _getDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'sari_pos_db.sqlite');
  }

  /// Backup DB to Downloads folder (Android) or Documents (desktop)
  static Future<String> backup() async {
    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('Database file not found at $dbPath');
    }

    Directory destDir;
    if (Platform.isAndroid) {
      destDir = Directory('/storage/emulated/0/Download');
      if (!await destDir.exists()) {
        destDir = await getApplicationDocumentsDirectory();
      }
    } else {
      destDir = await getApplicationDocumentsDirectory();
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final destPath = p.join(destDir.path, 'sari_pos_backup_$timestamp.sqlite');
    await dbFile.copy(destPath);
    return destPath;
  }

  /// Restore DB from a backup file path
  static Future<void> restore(String backupFilePath) async {
    final backupFile = File(backupFilePath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found: $backupFilePath');
    }
    final dbPath = await _getDbPath();
    await backupFile.copy(dbPath);
    // App must restart after restore for Drift to re-open the DB
  }

  /// Export products as CSV string
  static Future<String> exportProductsCsv(List<Map<String, dynamic>> rows) async {
    final buf = StringBuffer();
    buf.writeln('Name,Category,Price,Cost,Stock,Unit,Barcode,Active');
    for (final row in rows) {
      buf.writeln([
        _csv(row['name'] ?? ''),
        _csv(row['category'] ?? ''),
        _csv(row['price'] ?? ''),
        _csv(row['cost'] ?? ''),
        _csv(row['stock'] ?? ''),
        _csv(row['unit'] ?? ''),
        _csv(row['barcode'] ?? ''),
        _csv(row['active'] ?? ''),
      ].join(','));
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().substring(0, 10);
    final file = File(p.join(dir.path, 'sari_pos_products_$timestamp.csv'));
    await file.writeAsString(buf.toString());
    return file.path;
  }

  static String _csv(dynamic value) {
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }
}